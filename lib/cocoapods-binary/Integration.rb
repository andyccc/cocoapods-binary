require_relative 'helper/podfile_options'
require_relative 'helper/feature_switches'
require_relative 'helper/prebuild_sandbox'
require_relative 'helper/passer'
require_relative 'helper/names'
require_relative 'helper/target_checker'

require 'find'

HEADER_FILE_EXTNAMES = [".h", ".hpp"]


# NOTE:
# This file will only be loaded on normal pod install step
# so there's no need to check is_prebuild_stage



# Provide a special "download" process for prebuilded pods.
#
# As the frameworks is already exsited in local folder. We
# just create a symlink to the original target folder.
#
module Pod
    class Installer
        class PodSourceInstaller

            def install_for_prebuild!(standard_sanbox)
                if not Podfile::DSL.allow_local_pod
                    return if standard_sanbox.local? self.name
                end

                # make a symlink to target folder
                prebuild_sandbox = Pod::PrebuildSandbox.from_standard_sandbox(standard_sanbox)
                # if spec used in multiple platforms, it may return multiple paths
                target_names = prebuild_sandbox.existed_target_names_for_pod_name(self.name)

                
                def walk(path, &action)
                    return unless path.exist?
                    path.children.each do |child|
                        result = action.call(child, &action)
                        walk(child, &action) if result and child.directory?
                    end
                end
                def make_link(source, target)
                    source = Pathname.new(source)
                    target = Pathname.new(target)
                    
                    target.parent.mkpath unless target.parent.exist?
                    relative_source = source.relative_path_from(target.parent)

                    FileUtils.ln_sf(relative_source, target, verbose: true)
                end
                def mirror_with_symlink(source, basefolder, target_folder)
                    target = target_folder + source.relative_path_from(basefolder)
                    make_link(source, target)
                end
                
                def library_file_format
                    list = [".a" ,".framework", ".dSYM", ".bundle"]
                    return list unless Pod::Podfile::DSL.uses_frameworks_off
                    return list + HEADER_FILE_EXTNAMES
                end
                
                Pod::UI.puts "Prebuilding mark -11220- target_names : #{target_names}"
                
                #test /Users/yans/workplace/eclipse/testpodFramework/Pods/_Prebuild/Generated/MPNotificationView/MPNotificationView.h
#                f1 = Pathname.new("/Users/yans/workplace/eclipse/testpodFramework/Pods/_Prebuild/Generated/MPNotificationView/MPNotificationView/MPNotificationView.h")
#                f2 = Pathname.new("/Users/yans/workplace/eclipse/testpodFramework/Pods/_Prebuild/Generated/MPNotificationView/MPNotificationView.h")
#                f2.parent.mkpath unless f2.parent.exist?
#                FileUtils.cp_r(f1, f2, :remove_destination => true, :verbose => true)

                
                target_names.each do |name|

                    # symbol link copy all substructure
                    real_file_folder = prebuild_sandbox.framework_folder_path_for_target_name(name)
                    
                    Pod::UI.puts "Prebuilding mark -11221- real_file_folder : #{real_file_folder}"

                    
                    # If have only one platform, just place int the root folder of this pod.
                    # If have multiple paths, we use a sperated folder to store different
                    # platform frameworks. e.g. AFNetworking/AFNetworking-iOS/AFNetworking.framework
                    
                    target_folder = standard_sanbox.pod_dir(self.name)
                    target_folder += real_file_folder.basename if target_names.count > 1

                    Pod::UI.puts "Prebuilding mark -11222- target_folder : #{target_folder}"
                    
                    target_folder.rmtree if target_folder.exist?
                    target_folder.mkpath

                    path = real_file_folder
                    walk(path) do |child|
                        source = child
                        Pod::UI.puts "Prebuilding mark -11229- walk : #{source}, #{child.extname}"
                        
                        # only make symlink to file and `.framework` folder
                        if child.directory? and library_file_format().include? child.extname
                            mirror_with_symlink(source, path, target_folder)
                            next false  # return false means don't go deeper
                        elsif child.file?
                            mirror_with_symlink(source, path, target_folder)
                            next true
                        else
                            next true
                        end
                    end
                    
                    # symbol link copy resource for static framework
                    hash = Prebuild::Passer.resources_to_copy_for_static_framework || {}

                    path_objects = hash[name]
                    if path_objects != nil
                        path_objects.each do |object|
                            
                            target_file = Pathname.new(object.target_file_path)

                            # linking file bugs, first check exist.
                            make_link(object.real_file_path, object.target_file_path) unless target_file.exist?
                        end
                    end
                    
                    Pathname.new(target_folder).children.each do |child|
                        Pod::UI.puts "Prebuilding mark -11223- child : #{child}"
                    end
                    
                end # of for each
                
            end # of method

        end
    end
end


# Let cocoapods use the prebuild framework files in install process.
#
# the code only effect the second pod install process.
#
module Pod
    class Installer


        # Remove the old target files if prebuild frameworks changed
        def remove_target_files_if_needed

            changes = Pod::Prebuild::Passer.prebuild_pods_changes
            updated_names = []
            if changes == nil
                updated_names = PrebuildSandbox.from_standard_sandbox(self.sandbox).exsited_framework_pod_names
            else
                added = changes.added
                changed = changes.changed 
                deleted = changes.deleted 
                updated_names = added + changed + deleted
            end

            updated_names.each do |name|
                root_name = Specification.root_name(name)
                if not Podfile::DSL.allow_local_pod
                    next if self.sandbox.local?(root_name)
                end
                
                # delete the cached files
                target_path = self.sandbox.pod_dir(root_name)
                target_path.rmtree if target_path.exist?
                Logger(10010, "rmtree path", target_path)

                support_path = sandbox.target_support_files_dir(root_name)
                support_path.rmtree if support_path.exist?
                Logger(10011, "rmtree path", support_path)
            end

        end


        # Modify specification to use only the prebuild framework after analyzing
        old_method2 = instance_method(:resolve_dependencies)
        define_method(:resolve_dependencies) do

            # Remove the old target files, else it will not notice file changes
            self.remove_target_files_if_needed

            # call original
            old_method2.bind(self).()
            # ...
            # ...
            # ...
            # after finishing the very complex orginal function

            # check the pods
            # Although we have did it in prebuild stage, it's not sufficient.
            # Same pod may appear in another target in form of source code.
            # Prebuild.check_one_pod_should_have_only_one_target(self.prebuild_pod_targets)
            self.validate_every_pod_only_have_one_form

            
            # prepare
            cache = []

            def add_vendered_items(spec, platform, item_path, item_type)
                if spec.attributes_hash[platform] == nil
                    spec.attributes_hash[platform] = {}
                end
                
                vendored_items = spec.attributes_hash[platform][item_type] || []

                vendored_items = [vendored_items] if vendored_items.kind_of?(String)

                vendored_items += item_path
                Pod::UI.puts "Prebuilding mark -11500- #{spec}, #{platform}, #{item_path}, #{item_type}"
                
                spec.attributes_hash[platform][item_type] = vendored_items
            end
            
            def empty_source_files(spec)
                spec.attributes_hash["source_files"] = []
                #spec.attributes_hash["public_header_files"] = []
                ["ios", "watchos", "tvos", "osx"].each do |plat|
                    if spec.attributes_hash[plat] != nil
                        spec.attributes_hash[plat]["source_files"] = []
                        #spec.attributes_hash[plat]["public_header_files"] = []
                    end
                end
            end
            
            def get_file_path_by_name(path, name)
                Find.find(path) do |child|
                    file_name = File.basename(child).to_s
                    if file_name == name.to_s
                        return child
                    end
                end
                return ""
            end
            
            def get_file_patterns(target, name, platform, spec, sandbox, item_type)
                # sandbox.root valid ...
                
                prebuild_sandbox = Pod::PrebuildSandbox.from_standard_sandbox(sandbox)
                real_file_folder = prebuild_sandbox.framework_folder_path_for_target_name(name).to_s
                
                target_files = spec.attributes_hash[item_type] || []
                target_files = [target_files]  if target_files.kind_of?(String)
                
                path_list = Pod::Sandbox::PathList.new(real_file_folder)
                options = {
                    :dir_pattern => false,
                    :include_dirs => true,
                    :exclude_patterns => false,
                }
                
                path_list = path_list.glob(target_files, options).flatten.compact.uniq
                files = []
                path_list.each do |path|
                    file_path = path.realpath.to_s
                    file_path = file_path.gsub("#{real_file_folder}/", "") if file_path.start_with? real_file_folder
                    files.push(file_path) if not file_path.include? ".framework" or item_type.eql?("vendored_frameworks")
                end

                files = files.flatten.uniq
                
                return files
            end

            def find_vendered_headers(target, name, platform, spec, sandbox)
                files = get_file_patterns(target, name, platform, spec, sandbox, "public_header_files") || []

                # 有些不规范的库可能没有设置 public_header_files
                if Podfile::DSL.allow_public_headers or files.empty?
                    files += get_file_patterns(target, name, platform, spec, sandbox, "source_files")
                end

                files = files.flatten.uniq
                
                spec.attributes_hash["public_header_files"] = files
                spec.attributes_hash["source_files"] = files if not target.build_as_framework?
            end
            
            def find_vendored_libraries(target, name, platform, spec, sandbox)
                files = get_file_patterns(target, name, platform, spec, sandbox, "vendored_libraries")
                spec.attributes_hash["vendored_libraries"] = files
            end
            
            def find_vendored_frameworks(target, name, platform, spec, sandbox)
                target_files = spec.attributes_hash["vendored_frameworks"] || []
                files = get_file_patterns(target, name, platform, spec, sandbox, "vendored_frameworks")
                spec.attributes_hash["vendored_frameworks"] = files
            end
            
            def find_vendored_resources(target, name, platform, spec, sandbox)
                files = get_file_patterns(target, name, platform, spec, sandbox, "resources")
                spec.attributes_hash["resources"] = files
            end
            
            specs = self.analysis_result.specifications
            prebuilt_specs = (specs.select do |spec|
                self.prebuild_pod_names.include? spec.root.name
            end)

            all_spec_names = []
            prebuilt_specs.each do |spec|
                all_spec_names.push(spec.name)
            end
            
            dependencies_specs = []
            prebuilt_specs.each do |spec|
                dependencies = spec.attributes_hash["dependencies"] || {}
                dependencies.keys.each do |sp|
                    dependencies_specs.push(spec.name) if all_spec_names.include?(sp)
                end
            end
        
            dependencies_specs = dependencies_specs.flatten.uniq
    
            prebuilt_specs.each do |spec|
                Pod::UI.puts "Prebuilding mark -1122- #{spec.name}, #{spec.to_json}"
                Pod::UI.puts "Prebuilding mark -1222- #{spec.name}, #{spec.parent.to_json}"

#                all_resources = spec.attributes_hash["resource"] || []

                # Use the prebuild framworks as vendered frameworks
                # get_corresponding_targets
                targets = Pod.fast_get_targets_for_pod_name(spec.root.name, self.pod_targets, cache)
                targets.each do |target|
                    # the item_path rule is decided when `install_for_prebuild`,
                    # as to compitable with older version and be less wordy.
                    item_path = ""
                    item_type = ""
                    target_name = target.name
                    platform = target.platform.name.to_s
                    
                    if target.build_as_framework?
                        item_type = "vendored_frameworks"
                        item_path = target.framework_name
                    else
                        item_type = "vendored_libraries"
                        item_path = target.static_library_name
                    end

                    Pod::UI.puts "Prebuilding mark -11489 - #{item_path}"
                    Pod::UI.puts "Prebuilding mark -12302 - #{target.name}, #{target.pod_name}"

                    item_path = target_name + "/" + item_path if targets.count > 1
                    add_vendered_items(spec, platform, [item_path], item_type) if not dependencies_specs.include?(spec.name)
                    
                    find_vendered_headers(target, target_name, platform, spec, self.sandbox)
                    # find_vendored_libraries(target, target_name, platform, spec, self.sandbox)
                    # find_vendored_frameworks(target, target_name, platform, spec, self.sandbox)
                    # find_vendored_resources(target, target_name, platform, spec, self.sandbox)

                    Pod::UI.puts "Prebuilding mark -1146-#{spec},#{spec.name}, #{platform}, #{item_path}, #{item_type}, #{targets.count}"


                    Pod::UI.puts "Prebuilding mark -1150- #{item_path}"
                    Pod::UI.puts "Prebuilding mark -11501- #{self.sandbox.root}"

                    empty_source_files(spec) if target.build_as_framework?

                    Pod::UI.puts "Prebuilding mark -11502- #{target.root_spec}"
                    Pod::UI.puts "Prebuilding mark -115023- #{target.root_spec.to_s}"
                    Pod::UI.puts "Prebuilding mark -11503- #{target.sandbox}, #{target.pod_name}"
                    
#                    prebuild_sandbox = Pod::PrebuildSandbox.from_standard_sandbox(sandbox)
#                    real_file_folder = prebuild_sandbox.framework_folder_path_for_target_name(target.name)
#
#                    consumer = target.root_spec.consumer(target.platform.name)
#                    pod_path = self.sandbox.pod_dir(target.pod_name);
#                    Pod::UI.puts "Prebuilding mark -11505- #{target.pod_name}, #{target.name}, #{pod_path}, #{prebuild_sandbox}"
#
#                    file_accessor = Pod::Sandbox::FileAccessor.new(real_file_folder, consumer)
#                    resources = file_accessor.resources || []
#                    Pod::UI.puts "Prebuilding mark -11504- #{target.name}, #{resources}"
#                    resources += spec.attributes_hash["resource"] || []
#                    Pod::UI.puts "Prebuilding mark -11506- #{target.name}, #{resources}"


#                    rs = spec.attributes_hash["resource"]
#                    Pod::UI.puts "Prebuilding mark -11505-  #{rs}"
#                    Pod::UI.puts "Prebuilding mark -11506- #{spec.root}"
#                    Pod::UI.puts "Prebuilding mark -11507- #{target.resource_paths}"
                    
#                    target.resource_paths.values.each do |resource|
#                        all_resources += resource if resource.count > 0
#                    end

                        # spec 中添加 resources
#                    hash = Prebuild::Passer.resources_to_copy_for_static_framework || {}
#                    Pod::UI.puts "Prebuilding mark -3330- #{hash}"
#                    path_objects = hash[target.name]
#                    if path_objects != nil
#                        path_objects.each do |object|
#                            real_file_path = object.target_file_path #real_file_path target_file_path
#                            resources = spec.attributes_hash["resources"] || []
#                            resources = [resources] if resources.kind_of?(String)
#                            resources += [real_file_path] if not resources.include?(real_file_path)
#                            spec.attributes_hash["resources"] = resources
#
#                            Pod::UI.puts "Prebuilding mark -12501- spec resources #{resources}"
#                        end
#                    end

                end

                Pod::UI.puts "Prebuilding mark -12300 -  spec json: #{spec.to_json}"




                # add resource files
#                prebuild_sandbox = Pod::PrebuildSandbox.from_standard_sandbox(self.sandbox)
#                standard_sandbox_path = prebuild_sandbox.standard_sanbox_path
#
#                all_resources = all_resources.flatten.uniq || []
#                all_resources = all_resources.map{|path|
#                    path = path.gsub("${PODS_ROOT}", standard_sandbox_path.to_s) if path.start_with? "${PODS_ROOT}"
#                }
#                # spec.attributes_hash["resource"] = all_resources
#                Pod::UI.puts "Prebuilding mark -11507- #{all_resources}"





                # Clean the source files
                # we just add the prebuilt framework to specific platform and set no source files 
                # for all platform, so it doesn't support the sence that 'a pod perbuild for one
                # platform and not for another platform.'
                # empty_source_files(spec)

                # to remove the resurce bundle target. 
                # When specify the "resource_bundles" in podspec, xcode will generate a bundle 
                # target after pod install. But the bundle have already built when the prebuit
                # phase and saved in the framework folder. We will treat it as a normal resource
                # file.
                # https://github.com/leavez/cocoapods-binary/issues/29
                if spec.attributes_hash["resource_bundles"]
                    bundle_names = spec.attributes_hash["resource_bundles"].keys
                    spec.attributes_hash["resource_bundles"] = nil 
                    spec.attributes_hash["resources"] ||= []
                    spec.attributes_hash["resources"] += bundle_names.map{|n| n+".bundle"}
                end

                # to avoid the warning of missing license
                spec_parent = spec.parent
                license = spec_parent.attributes_hash["license"] || {} if spec_parent != nil
                spec.attributes_hash["license"] = license || {}
                
                license = spec.attributes_hash["license"]
                Pod::UI.puts "Prebuilding mark -12301 -  license: #{license}"
            end

        end


        # Override the download step to skip download and prepare file in target folder
        old_method = instance_method(:install_source_of_pod)
        define_method(:install_source_of_pod) do |pod_name|

            # copy from original
            pod_installer = create_pod_installer(pod_name)
            # \copy from original

            if self.prebuild_pod_names.include? pod_name
                pod_installer.install_for_prebuild!(self.sandbox)
            else
                pod_installer.install!
            end

            # copy from original
            @installed_specs.concat(pod_installer.specs_by_platform.values.flatten.uniq)
            # \copy from original
        end
    end
end

# A fix in embeded frameworks script.
#
# The framework file in pod target folder is a symblink. The EmbedFrameworksScript use `readlink`
# to read the read path. As the symlink is a relative symlink, readlink cannot handle it well. So 
# we override the `readlink` to a fixed version.
#
module Pod
    module Generator
        class EmbedFrameworksScript
            old_method = instance_method(:script)
            define_method(:script) do
                script = old_method.bind(self).()
                patch = <<-SH.strip_heredoc
                    #!/bin/sh
                
                    # ---- this is added by cocoapods-binary ---
                    # Readlink cannot handle relative symlink well, so we override it to a new one
                    # If the path isn't an absolute path, we add a realtive prefix.
                    old_read_link=`which readlink`
                    readlink () {
                        path=`$old_read_link $1`;
                        if [ $(echo "$path" | cut -c 1-1) = '/' ]; then
                            echo $path;
                        else
                            echo "`dirname $1`/$path";
                        fi
                    }
                    # --- 
                SH

                # patch the rsync for copy dSYM symlink
                script = script.gsub "rsync --delete", "rsync --copy-links --delete"
                
                patch + script

            end
        end
    end
end
