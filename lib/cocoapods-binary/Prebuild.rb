require_relative 'helper/passer'
require_relative 'helper/target_checker'
require_relative 'helper/prebuild_sandbox_fetch'
require_relative 'rome/build_framework'

# patch prebuild ability
module Pod
    class Installer

        
        private

        def local_manifest 
            if not @local_manifest_inited
                @local_manifest_inited = true
                raise "This method should be call before generate project" unless self.analysis_result == nil
                @local_manifest = self.sandbox.manifest
            end
            @local_manifest
        end

        # @return [Analyzer::SpecsState]
        def prebuild_pods_changes
            return nil if local_manifest.nil?
            if @prebuild_pods_changes.nil?
                changes = local_manifest.detect_changes_with_podfile(podfile)
                @prebuild_pods_changes = Analyzer::SpecsState.new(changes)
                # save the chagnes info for later stage
                Pod::Prebuild::Passer.prebuild_pods_changes = @prebuild_pods_changes 
            end
            @prebuild_pods_changes
        end

        
        public 

        # check if need to prebuild
        def have_exact_prebuild_cache?

            # check if need build frameworks
            return false if local_manifest == nil
            
            changes = prebuild_pods_changes
            added = changes.added
            changed = changes.changed 
            unchanged = changes.unchanged
            deleted = changes.deleted 
            
            exsited_framework_pod_names = sandbox.exsited_framework_pod_names
            missing = unchanged.select do |pod_name|
                not exsited_framework_pod_names.include?(pod_name)
            end

            needed = (added + changed + deleted + missing)
            
            return needed.empty?
        end
        
        
        # The install method when have completed cache
        def install_when_cache_hit!
            # just print log
            self.sandbox.exsited_framework_target_names.each do |name|
                Pod::UI.puts "🚀  Using cache #{name}".blue
            end
        end
    
        def config_umbrella_header(output_path, target_name, headers)
            umbrella_header = "#{output_path}/#{target_name}.framework/Headers/#{target_name}-umbrella.h"
            umbrella_content = File.read(umbrella_header)
            
            private_header = ""
            headers.each do |header|
                name = header.basename.to_s
                private_header.concat("\n#import \"#{name}\"") if not umbrella_content.include? name
            end
            
            if not private_header.empty?
                umbrella_content.concat("\n/// private headers begin")
                umbrella_content.concat(private_header)
                umbrella_content.concat("\n/// private headers end")
            end

            File.write(umbrella_header, umbrella_content)
        end

        # Build the needed framework files
        def prebuild_frameworks! 

            # build options
            sandbox_path = sandbox.root
            existed_framework_folder = sandbox.generate_framework_path
            bitcode_enabled = Pod::Podfile::DSL.bitcode_enabled
            targets = []
            
            if local_manifest != nil

                changes = prebuild_pods_changes
                added = changes.added
                changed = changes.changed 
                unchanged = changes.unchanged
                deleted = changes.deleted 
    
                existed_framework_folder.mkdir unless existed_framework_folder.exist?
                exsited_framework_pod_names = sandbox.exsited_framework_pod_names
    
                # additions
                missing = unchanged.select do |pod_name|
                    not exsited_framework_pod_names.include?(pod_name)
                end


                root_names_to_update = (added + changed + missing)

                # transform names to targets
                cache = []
                targets = root_names_to_update.map do |pod_name|
                    tars = Pod.fast_get_targets_for_pod_name(pod_name, self.pod_targets, cache)
                    if tars.nil? || tars.empty?
                        raise "There's no target named (#{pod_name}) in Pod.xcodeproj.\n #{self.pod_targets.map(&:name)}" if t.nil?
                    end
                    tars
                end.flatten

                # add the dendencies
                dependency_targets = targets.map {|t| t.recursive_dependent_targets }.flatten.uniq || []
                targets = (targets + dependency_targets).uniq
            else
                targets = self.pod_targets
            end
            
            # frameworks which mark binary true, should be filtered before prebuild
            prebuild_framework_pod_names = []
            podfile.target_definition_list.each do |target_definition|
                next if target_definition.prebuild_framework_pod_names.empty?
                prebuild_framework_pod_names += target_definition.prebuild_framework_pod_names
            end

            
            # filter local pods
            targets = targets.reject {|pod_target| sandbox.local?(pod_target.pod_name) } if not Podfile::DSL.allow_local_pod

            # filter dependency
            # targets = targets.select {|pod_target| prebuild_framework_pod_names.include?(pod_target.pod_name) }
            
            # build!
            Pod::UI.puts "🚀  Prebuild files (total #{targets.count})"
            Pod::Prebuild.remove_build_dir(sandbox_path)
            
            targets = targets.reject { |pod_target| Pod::Podfile::DSL.binary_white_list.include?(pod_target.pod_name) }
            
            targets.each do |target|
                
                target_name = target.name

                UI.section "🍭  Prebuild Ready to build #{target_name}".blue do
                    if !target.should_build?
                        Pod::UI.puts "🏇  Skipping #{target.label}"
                        next
                    end

                    output_path = sandbox.framework_folder_path_for_target_name(target_name)
                    output_path.mkpath unless output_path.exist?
                    
                    need_pull = Podfile::DSL.binary_cache
                    need_push = false
                    need_build = false

                    generate_path = sandbox.generate_framework_path.to_s
                    rsync_server_url = Podfile::DSL.rsync_server_url
                    spec = target.root_spec
                    
                    
                    loop do
                        if not need_pull
                            need_build = true
                            break
                        end
                        
                        if sandbox.local?target_name and not Podfile::DSL.local_binary_cache
                            need_build = true
                            break
                        end
                        
                        exist_remote_framework = Pod::PrebuildFetch.fetch_remote_framework_for_target(spec.name, spec.version, generate_path, rsync_server_url)
                        if not exist_remote_framework
                            Pod::UI.puts "💦  Non exist remote cache, #{target_name}".blue
                            
                            need_build = true
                            need_push = true
                            break
                        end
                        
                        Pod::UI.puts "🎁  Exist remote cache, #{target_name}".green

                        break
                    end

                    if need_build
                        Pod::Prebuild.build(sandbox_path, target, output_path, bitcode_enabled, Podfile::DSL.custom_build_options, Podfile::DSL.custom_build_options_simulator)
                    end
                    
                    if need_push
                        Podfile::DSL.builded_list.push(target_name)
                        Pod::PrebuildFetch.sync_prebuild_framework_to_server(spec.name, spec.version, generate_path, rsync_server_url)
                    end
                    
                    
                    
                    # public private headers
                    if Podfile::DSL.allow_public_headers and target.build_as_framework?
                        headers = []
                        target.file_accessors.each do |fa|
                            headers += fa.headers || []
                        end

                        config_umbrella_header(output_path, target_name, headers)
                    end

                    
                    #  ...
                    #target.static_framework
                    #target.build_as_dynamic_library
                    #target.build_as_static_framework
                    
                    # save the resource paths for later installing
                    if !target.resource_paths.empty? #and target.build_as_dynamic?
                        framework_path = output_path
                        framework_path = framework_path + target.framework_name if target.build_as_framework?
                        
                        standard_sandbox_path = sandbox.standard_sanbox_path

                        resources = begin
                            if Pod::VERSION.start_with? "1.5"
                                target.resource_paths
                            else
                                # resource_paths is Hash{String=>Array<String>} on 1.6 and above
                                # (use AFNetworking to generate a demo data)
                                # https://github.com/leavez/cocoapods-binary/issues/50
                                target.resource_paths.values.flatten
                            end
                        end
                        raise "Wrong type: #{resources}" unless resources.kind_of? Array

                        path_objects = resources.map do |path|
                            object = Prebuild::Passer::ResourcePath.new
                            #object.real_file_path = framework_path + File.basename(path)
                            object.real_file_path = path.gsub('${PODS_ROOT}', sandbox.generate_framework_path.to_s) if path.start_with? '${PODS_ROOT}'
                            
                            object.target_file_path = path.gsub('${PODS_ROOT}', standard_sandbox_path.to_s) if path.start_with? '${PODS_ROOT}'
                            object.target_file_path = path.gsub("${PODS_CONFIGURATION_BUILD_DIR}", standard_sandbox_path.to_s) if path.start_with? "${PODS_CONFIGURATION_BUILD_DIR}"
                            
                            object
                        end
                        # mark Generated files to Pods/xx
                        Prebuild::Passer.resources_to_copy_for_static_framework[target_name] = path_objects
                        
    #                    Logger(1000, "path_objects", path_objects)
    #                    Logger(1001, "target.name", target.name)

                    end
                
                end

            end
            
            # remove build path
            Pod::Prebuild.remove_build_dir(sandbox_path) if Podfile::DSL.clean_build_dir
            
            def copy_vendered_files(lib_paths, root_path, target_folder)
                lib_paths.each do |lib_path|
                    relative = lib_path.relative_path_from(root_path)
                    destination = target_folder + relative
                    destination.dirname.mkpath unless destination.dirname.exist?
                    FileUtils.cp_r(lib_path, destination, :remove_destination => true, :verbose => Pod::Podfile::DSL.verbose_log)
                end
            end
            
            def copy_vendered_headers(lib_paths, root_path)
                lib_paths.each do |lib_path|
                    FileUtils.cp_r(lib_path, root_path, :remove_destination => true, :verbose => Pod::Podfile::DSL.verbose_log)
                end
            end
            
            
            # copy vendored libraries and frameworks
            targets.each do |target|
                root_path = self.sandbox.pod_dir(target.name)
                target_folder = sandbox.framework_folder_path_for_target_name(target.name)
                
                # If target shouldn't build, we copy all the original files
                # This is for target with only .a and .h files
                if not target.should_build? 
                    Prebuild::Passer.target_names_to_skip_integration_framework << target.name

                    FileUtils.cp_r(root_path, target_folder, :remove_destination => true, :verbose => Pod::Podfile::DSL.verbose_log)
                    next
                end
                
#                Logger(10032, "dependencies", target.dependencies)

                
                # copy to Generated
                target.spec_consumers.each do |consumer|
                    file_accessor = Sandbox::FileAccessor.new(root_path, consumer)
                    
                    lib_paths = []

                    #add frameworks
                    lib_paths += file_accessor.vendored_frameworks || []
                    
                    if Pod::VERSION.start_with? "1.9"
                        lib_paths += file_accessor.vendored_xcframeworks || [] # cocoapods version 1.9.0+
                    end
                    
                    #add libraries
                    lib_paths += file_accessor.vendored_libraries || []
                    #add headers
                    lib_paths += file_accessor.headers || []
                    
                    lib_paths += file_accessor.docs || []

                    #add resources
                    lib_paths += file_accessor.resources || []
                    
                    lib_paths += file_accessor.resource_bundles.values if not file_accessor.resource_bundles.nil?
                    lib_paths += file_accessor.resource_bundle_files || []

                    #add license
                    lib_paths += [file_accessor.license] if not file_accessor.license.nil?
                    lib_paths += [file_accessor.spec_license] if not file_accessor.spec_license.nil?

                    #add readme
                    lib_paths += [file_accessor.readme] if not file_accessor.readme.nil?
                    

                    #developer_files ⇒ Array<Pathname> Paths to include for local pods to assist in development.

                    copy_vendered_files(lib_paths, root_path, target_folder)

                    # framework not same
                    if Podfile::DSL.allow_public_headers and target.build_as_framework?
                        headers = file_accessor.headers || []
                        copy_vendered_headers(headers, "#{target_folder}/#{target.framework_name}/Headers")
                    end
                end
            end

            # save the pod_name for prebuild framwork in sandbox 
            targets.each do |target|
                sandbox.save_pod_name_for_target target
            end
            
            
            # Remove useless files
            # remove useless pods
            all_needed_names = self.pod_targets.map(&:name).uniq
            useless_target_names = sandbox.exsited_framework_target_names.reject do |name| 
                all_needed_names.include? name
            end
            
            
            useless_target_names.each do |name|
                path = sandbox.framework_folder_path_for_target_name(name)
                #path.rmtree if path.exist?
                FileUtils.rm_r(path.realpath, :verbose => Pod::Podfile::DSL.verbose_log) if path.exist?
            end
            
            
            if not Podfile::DSL.dont_remove_source_code
                # only keep manifest.lock and framework folder in _Prebuild
                to_remain_files = ["Manifest.lock", File.basename(existed_framework_folder)]
                to_delete_files = sandbox_path.children.select do |file|
                    filename = File.basename(file)
                    not to_remain_files.include?(filename)
                end
                to_delete_files.each do |path|
                    #path.rmtree if path.exist?
                    FileUtils.rm_r(path.realpath, :verbose => Pod::Podfile::DSL.verbose_log) if path.exist?
                end
            else 
                # just remove the tmp files
                path = sandbox.root + 'Manifest.lock.tmp'
                #path.rmtree if path.exist?
                FileUtils.rm_r(path.realpath, :verbose => Pod::Podfile::DSL.verbose_log) if path.exist?
            end

        end
        
        
        # patch the post install hook
        old_method2 = instance_method(:run_plugins_post_install_hooks)
        define_method(:run_plugins_post_install_hooks) do

            old_method2.bind(self).()
            if Pod::is_prebuild_stage

                UI.section '🔨  Prebuild Pods begin ...' do
                    self.prebuild_frameworks!
                end

            end
        end


    end
end
