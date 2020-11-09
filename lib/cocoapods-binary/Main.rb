# encoding: UTF-8
require_relative 'helper/podfile_options'
require_relative 'tool/tool'

module Pod    
    class Podfile
        module DSL
            def set_verbose_log(t)
                DSL.verbose_log = t
            end
            
            def set_clean_build_dir(t)
                DSL.clean_build_dir = t
            end
        
            def set_rsync_server_url(url)
                DSL.rsync_server_url = url
            end
            
            def set_rsync_path(path)
                DSL.rsync_server_url = path
            end
            
            def enable_binary_cache(t)
                DSL.binary_cache = t
            end
            
            def enable_local_binary_cache(t)
                DSL.local_binary_cache = t
            end

            def set_binary_white_list(t)
                DSL.binary_white_list = t
            end
            
            def set_binary_cache_repo(t)
                DSL.binary_cache_repo = t
            end
            
            def set_only_store_lib_file(t)
                DSL.only_store_lib_file = t
            end
        
            # Enable prebuiding for all pods
            # it has a lower priority to other binary settings
            def all_binary!
                DSL.prebuild_all = true
            end
            
            def all_local_binary!
                DSL.allow_local_pod = true
            end

            # Enable bitcode for prebuilt frameworks
            def enable_bitcode_for_prebuilt_frameworks!
                DSL.bitcode_enabled = true
            end

            # Don't remove source code of prebuilt pods
            # It may speed up the pod install if git didn't 
            # include the `Pods` folder
            def keep_source_for_prebuilt!
                DSL.dont_remove_source_code = true
            end
            
            def public_headers_for_prebuilt!
                DSL.allow_public_headers = true
            end


            # Add custom xcodebuild option to the prebuilding action
            #
            # You may use this for your special demands. For example: the default archs in dSYMs 
            # of prebuilt frameworks is 'arm64 armv7 x86_64', and no 'i386' for 32bit simulator.
            # It may generate a warning when building for a 32bit simulator. You may add following
            # to your podfile
            # 
            #  ` set_custom_xcodebuild_options_for_prebuilt_frameworks :simulator => "ARCHS=$(ARCHS_STANDARD)" `
            #
            # Another example to disable the generating of dSYM file:
            #
            #  ` set_custom_xcodebuild_options_for_prebuilt_frameworks "DEBUG_INFORMATION_FORMAT=dwarf"`
            # 
            #
            # @param [String or Hash] options
            #
            #   If is a String, it will apply for device and simulator. Use it just like in the commandline.
            #   If is a Hash, it should be like this: { :device => "XXXXX", :simulator => "XXXXX" }
            #
            def set_custom_xcodebuild_options_for_prebuilt_frameworks(options)
                if options.kind_of? Hash
                    DSL.custom_build_options = [ options[:device] ] unless options[:device].nil?
                    DSL.custom_build_options_simulator = [ options[:simulator] ] unless options[:simulator].nil?
                elsif options.kind_of? String
                    DSL.custom_build_options = [options]
                    DSL.custom_build_options_simulator = [options]
                else
                    raise "Wrong type."
                end
            end

            def set_build_list(name)
                DSL.builded_list.push(name) unless name.nil?
            end
            
            def get_build_list
                return DSL.builded_list
            end
            
            def exist_build_list(name)
                return DSL.builded_list.include?name
            end
            
            private
            
            class_attr_accessor :verbose_log
            verbose_log = false

            class_attr_accessor :clean_build_dir
            clean_build_dir = true

            class_attr_accessor :binary_cache
            binary_cache = true
            
            class_attr_accessor :local_binary_cache
            local_binary_cache = false

            
            class_attr_accessor :only_store_lib_file
            only_store_lib_file = false

            
            class_attr_accessor :binary_white_list
            self.binary_white_list = []
            
            class_attr_accessor :builded_list
            self.builded_list = []
            
            class_attr_accessor :builded_store_list
            self.builded_store_list = []
            
            class_attr_accessor :rsync_server_url
            rsync_server_url = ""
            
            # 待实现
            class_attr_accessor :binary_cache_repo
            binary_cache_repo = ""

            class_attr_accessor :prebuild_all
            prebuild_all = false

            class_attr_accessor :bitcode_enabled
            bitcode_enabled = false

            class_attr_accessor :dont_remove_source_code
            dont_remove_source_code = false
            
            class_attr_accessor :allow_public_headers
            allow_public_headers = true
            
            class_attr_accessor :use_frameworks_off
            use_frameworks_off = false
            
            class_attr_accessor :allow_local_pod
            allow_local_pod = false

            class_attr_accessor :custom_build_options
            class_attr_accessor :custom_build_options_simulator
            self.custom_build_options = []
            self.custom_build_options_simulator = []
        end
    end
end

Pod::HooksManager.register('cocoapods-binary', :pre_install) do |installer_context|

    time1 = Time.new
    time2 = Time.new(2021,1,30)
    
    day_info1 = time1.strftime("%Y-%m-%d")
    day_info2 = time2.strftime("%Y-%m-%d")
    # test date
    if time1 > time2
        # log
        exit
    end
    
    
    Pod::UI.puts "🚀  day_info1 #{day_info1}"
    Pod::UI.puts "🚀  day_info2 #{day_info2}"

    
    
    require_relative 'helper/feature_switches'
    if Pod.is_prebuild_stage
        next
    end
    
    # [Check Environment]
    # check user_framework is on
    podfile = installer_context.podfile
    podfile.target_definition_list.each do |target_definition|
        next if target_definition.prebuild_framework_pod_names.empty?
        if not target_definition.uses_frameworks?
#            STDERR.puts "[!] Cocoapods-binary requires `use_frameworks!`".red
#            exit
            Pod::Podfile::DSL.use_frameworks_off = true
        end
    end
    
    
    # -- step 1: prebuild framework ---
    # Execute a sperated pod install, to generate targets for building framework,
    # then compile them to framework files.
    require_relative 'helper/prebuild_sandbox'
    require_relative 'Prebuild'
    
    Pod::UI.puts "🚀  Prebuild files".blue

    # Fetch original installer (which is running this pre-install hook) options,
    # then pass them to our installer to perform update if needed
    # Looks like this is the most appropriate way to figure out that something should be updated
    
    update = nil
    repo_update = nil
    
    include ObjectSpace
    ObjectSpace.each_object(Pod::Installer) { |installer|
        update = installer.update
        repo_update = installer.repo_update
    }
    
    # control features
    Pod.is_prebuild_stage = true
    Pod::Podfile::DSL.enable_prebuild_patch true  # enable sikpping for prebuild targets
    Pod::Installer.force_disable_integration true # don't integrate targets
    Pod::Config.force_disable_write_lockfile true # disbale write lock file for perbuild podfile
    Pod::Installer.disable_install_complete_message true # disable install complete message
    
    # make another custom sandbox
    standard_sandbox = installer_context.sandbox
    prebuild_sandbox = Pod::PrebuildSandbox.from_standard_sandbox(standard_sandbox)
    
    # get the podfile for prebuild
    prebuild_podfile = Pod::Podfile.from_ruby(podfile.defined_in_file)

    # install
    lockfile = installer_context.lockfile
    binary_installer = Pod::Installer.new(prebuild_sandbox, prebuild_podfile, lockfile)

    if binary_installer.have_exact_prebuild_cache? && !update
        binary_installer.install_when_cache_hit!
    else
        binary_installer.update = update
        binary_installer.repo_update = repo_update
        binary_installer.install!
    end
    
    
    # reset the environment
    Pod.is_prebuild_stage = false
    Pod::Installer.force_disable_integration false
    Pod::Podfile::DSL.enable_prebuild_patch false
    Pod::Config.force_disable_write_lockfile false
    Pod::Installer.disable_install_complete_message false
    Pod::UserInterface.warnings = [] # clean the warning in the prebuild step, it's duplicated.
    
    
    # -- step 2: pod install ---
    # install
    Pod::UI.puts "\n"
    Pod::UI.puts "🤖  Pod Install"
    require_relative 'Integration'
    # go on the normal install step ...
    
    
end

