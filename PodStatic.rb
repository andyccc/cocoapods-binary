module PodStatic
    
	TARGET_SUPPORT_FILE_PATH = 'Pods/Target Support Files/'
	XCCONFIG_FILE_EXTENSION = 'xcconfig'
	LIBRARY_SEARCH_PATH_KEY = 'LIBRARY_SEARCH_PATHS'
	FRAMEWORK_SEARCH_PATH_KEY = 'FRAMEWORK_SEARCH_PATHS'
	OTHER_CFLAGS_KEY = 'OTHER_CFLAGS'
	STATIC_LIBRARY_DIR = 'Static'
	PODS_ROOT = '${PODS_ROOT}'
    DEFAULT_LIBRARY_DIR = '\${PODS_CONFIGURATION_BUILD_DIR}'
	PODS_ROOT_DIR = 'Pods'
	PRODUCT_TYPE_FRAMEWORK = 'com.apple.product-type.framework'
	VALID_ARCHS_KEY = 'VALID_ARCHS'

	FS = File::SEPARATOR

    LIB_DEBUG = "Debug"
    LIB_RELEASE = "Release"
    LIBS = [LIB_DEBUG, LIB_RELEASE]

    $_SKIP_LIBS = []
	$_CONFIG_MAPPINGS = {}

	$_ENABLE_STATIC_LIB = ENV['ENABLE_STATIC_LIB']
	$_FORCE_BUILD = ENV['FORCE_BUILD']
	$_SIMULATOR_SUPPORT = false
	$_AUTO_VALID_ARCHS = false
	$_DEFAULT_ARCHS = "armv7 armv7s arm64 arm64e"
	# $_DEFAULT_SIMULATOR_ARCHS = "i386 x86_64"
	$_DEFAULT_SIMULATOR_ARCHS = "x86_64"
	$_USE_FRAMEWORKS = false

    def PodStatic.targetLibPath(configName)
    	return PODS_ROOT + FS + STATIC_LIBRARY_DIR + FS + configName
    end

	def PodStatic.updateConfig(path, configName, libs)
		targetConfig = PodStatic.validConfigName(configName)
		Pod::UI.message "- PodStatic: updateConfig --->>> " + configName + "[" + targetConfig + "]"
        config = Xcodeproj::Config.new(path)
		lib_search_path = config.attributes[LIBRARY_SEARCH_PATH_KEY]
		libRegex = libs.join('|')
		new_lib_search_path = lib_search_path.gsub!(/#{DEFAULT_LIBRARY_DIR}\/(#{libRegex})/) {
            |str| str.gsub!(/#{DEFAULT_LIBRARY_DIR}/, PodStatic.targetLibPath(targetConfig))
		}
		config.attributes[LIBRARY_SEARCH_PATH_KEY] = new_lib_search_path
		config.save_as(Pathname.new(path))
	end

	def PodStatic.updateFrameConfig(path, configName, libs)
		targetConfig = PodStatic.validConfigName(configName)
        Pod::UI.message "- PodStatic: updateFrameConfig --->>> " + configName + "[" + targetConfig + "]"
		config = Xcodeproj::Config.new(path)
		framework_search_path = config.attributes[FRAMEWORK_SEARCH_PATH_KEY]
		libRegex = libs.join('|')
		new_framework_search_path = framework_search_path.gsub(/#{DEFAULT_LIBRARY_DIR}\/(#{libRegex})/) {
			|str| str.gsub(/#{DEFAULT_LIBRARY_DIR}/, PodStatic.targetLibPath(targetConfig))
		}
		config.attributes[FRAMEWORK_SEARCH_PATH_KEY] = new_framework_search_path
		other_cflags = config.attributes[OTHER_CFLAGS_KEY]
		new_other_cflags = other_cflags.gsub(/#{DEFAULT_LIBRARY_DIR}\/(#{libRegex})/) {
			|str| str.gsub(/#{DEFAULT_LIBRARY_DIR}/, PodStatic.targetLibPath(targetConfig))
		}
		config.attributes[OTHER_CFLAGS_KEY] = new_other_cflags
		config.save_as(Pathname.new(path))
	end

	def PodStatic.updateEmbedFrameworkScript(path, configs, libs)
		embed_framework_script = ""
		libRegex = libs.join('|')
		configName = ""
		File.open(path, 'r').each_line do |line|
			configs.each do |config|
				line.gsub(/"\$CONFIGURATION" == "(#{config.name})"/) {
					configName = config.name
				}
			end
			embed_framework_script += line.gsub(/install_framework \"\${BUILT_PRODUCTS_DIR}\/(#{libRegex})/) {
				|str| str.gsub(/\${BUILT_PRODUCTS_DIR}/, PodStatic.targetLibPath(PodStatic.validConfigName(configName)))
			}
		end
		File.open(path, "w") { |io| io.write(embed_framework_script) }
	end

	def PodStatic.validConfigName(configName)
		if !(LIBS.include?(configName))

			if $_CONFIG_MAPPINGS[configName]
				return $_CONFIG_MAPPINGS[configName]
			end

			return LIB_RELEASE
		end
		return configName
	end

	def PodStatic.updateXCConfig(target, libs)
		targetName = target.name
		Pod::UI.message "- PodStatic: Updating #{targetName} xcconfig files"

		configs = target.build_configurations
		configs.each do |config|
            configName = config.name                                   
			configPath = TARGET_SUPPORT_FILE_PATH + targetName + FS + targetName + '.' + configName.downcase + '.' + XCCONFIG_FILE_EXTENSION
			if target.product_type == PRODUCT_TYPE_FRAMEWORK
				updateFrameConfig(configPath, configName, libs)
			else
				updateConfig(configPath, configName, libs)
			end
		end

		if target.product_type == PRODUCT_TYPE_FRAMEWORK
			embed_framework_script_path = TARGET_SUPPORT_FILE_PATH + targetName + FS + targetName + '-frameworks.sh'
			Pod::UI.message "- PodStatic: Updating embed framework script"
			updateEmbedFrameworkScript(embed_framework_script_path, configs, libs)
		end
	end

	def PodStatic.findProjectTarget(project, libs)
		podTargets = []
		project.targets.each do |target|
			if (target.name.start_with?('Pods-'))
				podTargets.push(target)
			end
	    end
		return podTargets
	end

	def PodStatic.updatePodProject(project, libs)
		if libs.length >0
			Pod::UI.message "- PodStatic: Deleting dependencies on #{libs.join(', ')}"
			podTargets = PodStatic.findProjectTarget(project, libs)
			podTargets.each do |target|
				target.dependencies.delete_if { |dependency| libs.include?(dependency.name) }
		    	updateXCConfig(target, libs)
			end
		end
	end

	def PodStatic.buildLibs(installer, libs)
        project = installer.pods_project

		if libs.length > 0
			Pod::HooksManager.register('cocoapods-stats', :post_install) do |context, _|
				startTime1 = Time.new.to_i * 1000;
				Dir.chdir(PODS_ROOT_DIR){
					libs.each do |lib|
						startTime = Time.new.to_i * 1000;
						Pod::UI.message "- PodStatic: Building #{lib} ..."

						LIBS.each do |type|
							PodStatic.buildTypeLib(project, lib, libs, type)
						end

						endTime = Time.new.to_i * 1000 - startTime;
						Pod::UI.message "- PodStatic: Building #{lib} Time #{endTime}ms"
					end
				}
				Pod::UI.message "- PodStatic: Removing derived files"
				`rm -rf build`

				endTime1 = Time.new.to_i * 1000 - startTime1;
				Pod::UI.warn "- PodStatic: All time #{endTime1}ms"
            end
		end
	end

	def PodStatic.currentArchs(project, libs)
		return

		if $_AUTO_VALID_ARCHS
			podTargets = PodStatic.findProjectTarget(project, libs)
			podTargets.each do |target|

				targetName = target.name
				target.build_configurations.each do |config|
		            configName = config.name                                   
					path = TARGET_SUPPORT_FILE_PATH + targetName + FS + targetName + '.' + configName.downcase + '.' + XCCONFIG_FILE_EXTENSION
					puts "---->>>>>>>1 " + path 
					# _config = Xcodeproj::Config.new(path)
					_validArchs = config.build_settings[VALID_ARCHS_KEY]
					
					if _validArchs
						$_DEFAULT_ARCHS = _validArchs
						puts "---->>>>>>>2 " + _validArchs 
					else
						puts "---->>>>>>>3 no " 
					end
				end
			end

			
			# puts "---->>>>>>>1 " + project.build_configuration_list.get_setting('VALID_ARCHS').to_s
			
			# targetName = podTarget.name
			# podTarget.build_configurations.each do |config|
	  #           configName = config.name                                   
			# 	path = TARGET_SUPPORT_FILE_PATH + targetName + FS + targetName + '.' + configName.downcase + '.' + XCCONFIG_FILE_EXTENSION
			# 	puts "---->>>>>>>1 " + path 
			# 	# _config = Xcodeproj::Config.new(path)
			# 	_validArchs = config.build_settings[VALID_ARCHS_KEY]
				
			# 	if _validArchs
			# 		$_DEFAULT_ARCHS = _validArchs
			# 		puts "---->>>>>>>2 " + _validArchs 
			# 	else
			# 		puts "---->>>>>>>3 no " 
			# 	end
			# end



			# project.targets.each do |target|
			#   	target.build_configurations.each do |config|
			#     	_validArchs = config.build_settings[VALID_ARCHS_KEY] 

			#     	if _validArchs
			# 			$_DEFAULT_ARCHS = _validArchs
			# 			puts "---->>>>>>>2 " + _validArchs 
			# 		else
			# 			puts "---->>>>>>>3 no " 
			# 		end

			#   	end
			# end


		end
	end

	def PodStatic.staticExist(project, lib, libs, type, build_dir, isFramework)
		matchArch = false
		matchSimulatorkArch = false

		libPath1 = build_dir + FS + "lib" + lib + ".a"
		libPath2 = build_dir + FS + lib + ".framework" + FS + lib

		if File.exist?(libPath1) && File.exist?(libPath2) 
			# cleaning dirt
			Pod::UI.message "- PodStatic: Cleaning dirt path, #{libPath1}, #{libPath2}, #{build_dir}"
			`rm -rf #{libPath1}`
			`rm -rf #{libPath2}`
			`rm -rf #{build_dir}`
			return false
		end

		libPath = isFramework ? libPath2 : libPath1

		if File.exist?(libPath)
			archs = `lipo -info #{libPath}`
			archs = archs.delete!("\n").split(/: /)[2].split(/ /)
			archs.each do |arch|
				$_DEFAULT_ARCHS.split(" ").each do |ac|
					if arch == ac
						matchArch = true
					end
				end

				if $_SIMULATOR_SUPPORT
					$_DEFAULT_SIMULATOR_ARCHS.split(" ").each do |ac2|
						if arch == ac2
							matchSimulatorkArch = true
						end
					end
				end
			end
		end

		if !$_SIMULATOR_SUPPORT
			return matchArch
		else
			return matchArch && matchSimulatorkArch
		end
	end

	def PodStatic.buildTypeLib(project, lib, libs, type)
		build_dir = STATIC_LIBRARY_DIR + FS + type + FS + lib

		# `xcodebuild clean -scheme #{lib}`
		# `xcodebuild -scheme #{lib} -configuration #{type} build CONFIGURATION_BUILD_DIR=#{build_dir} VALID_ARCHS="armv7 armv7s arm64" ONLY_ACTIVE_ARCH=NO`
		# `rm -rf #{build_dir + FS + '*.h'}`
		# return

		#xcodebuild -project ${xcode_project_path} -target ${target_name} ONLY_ACTIVE_ARCH=NO -configuration ${configuration} clean build -sdk iphoneos -arch "armv7" VALID_ARCHS="armv7 armv7s arm64" BUILD_DIR="${output_folder}/armv7"
		#xcodebuild -project ${xcode_project_path} -target ${target_name} ONLY_ACTIVE_ARCH=NO -configuration ${configuration} clean build -sdk iphoneos -arch "armv7s" VALID_ARCHS="armv7 armv7s arm64" BUILD_DIR="${output_folder}/armv7s"
		#xcodebuild -project ${xcode_project_path} -target ${target_name} ONLY_ACTIVE_ARCH=NO -configuration ${configuration} clean build -sdk iphoneos -arch "arm64" VALID_ARCHS="armv7 armv7s arm64" BUILD_DIR="${output_folder}/arm64"
		#xcodebuild -project ${xcode_project_path} -target ${target_name} ONLY_ACTIVE_ARCH=NO -configuration ${configuration} clean build -sdk iphonesimulator -arch "i386" VALID_ARCHS="i386 x86_64" BUILD_DIR="${output_folder}/i386"
		#xcodebuild -project ${xcode_project_path} -target ${target_name} ONLY_ACTIVE_ARCH=NO -configuration ${configuration} clean build -sdk iphonesimulator -arch "x86_64" VALID_ARCHS="i386 x86_64" BUILD_DIR="${output_folder}/x86_64"


		matchLibArch = !$_USE_FRAMEWORKS ? PodStatic.staticExist(project, lib, libs, type, build_dir, false) : false
		matchFrameworkArch = PodStatic.staticExist(project, lib, libs, type, build_dir, true)

		if !$_FORCE_BUILD 
			if matchLibArch || matchFrameworkArch
				Pod::UI.message "- PodStatic: Building #{lib} [#{type}] [#{PODS_ROOT_DIR}#{FS}#{build_dir}] exist and match!"
				return
			end
		end

		validArchs = $_DEFAULT_ARCHS

		if !$_SIMULATOR_SUPPORT
			Pod::UI.message "- PodStatic: Building #{lib} [iphoneos] [#{type}] [#{PODS_ROOT_DIR}#{FS}#{build_dir}]"

			`xcodebuild clean -scheme #{lib}`
			`xcodebuild -scheme #{lib} ONLY_ACTIVE_ARCH=NO -configuration #{type} clean build -sdk iphoneos VALID_ARCHS="#{validArchs}" CONFIGURATION_BUILD_DIR=#{build_dir}`
			`rm -rf #{build_dir + FS + '*.h'}`
			return
		end
		
        iphoneos_dir = build_dir + FS + "iphoneos"
		Pod::UI.message "- PodStatic: Building #{lib} [iphoneos] [#{type}] [#{PODS_ROOT_DIR}#{FS}#{iphoneos_dir}]"
		
		`xcodebuild clean -scheme #{lib}`
		`xcodebuild -scheme #{lib} ONLY_ACTIVE_ARCH=NO -configuration #{type} clean build -sdk iphoneos ARCHS="#{validArchs}" VALID_ARCHS="armv7 armv7s arm64" CONFIGURATION_BUILD_DIR=#{iphoneos_dir}`
		# single one pack
		# `xcodebuild -scheme #{lib} ONLY_ACTIVE_ARCH=NO -configuration #{type} clean build -sdk iphoneos -arch "armv7s" VALID_ARCHS="armv7 armv7s arm64" CONFIGURATION_BUILD_DIR=#{iphoneos_dir}`

		validSimulatorArchs = $_DEFAULT_SIMULATOR_ARCHS
        iphonesimulator_dir = build_dir + FS + "iphonesimulator"
		Pod::UI.message "- PodStatic: Building #{lib} [iphonesimulator] [#{type}] [#{PODS_ROOT_DIR}#{FS}#{iphonesimulator_dir}]"
                                                
		`xcodebuild clean -scheme #{lib}`
		`xcodebuild -scheme #{lib} ONLY_ACTIVE_ARCH=NO -configuration #{type} clean build -sdk iphonesimulator VALID_ARCHS="#{validSimulatorArchs}" CONFIGURATION_BUILD_DIR=#{iphonesimulator_dir}`


	    if File.directory? iphoneos_dir and File.directory? iphonesimulator_dir 
	        Dir.foreach(iphoneos_dir) do |file|
	            if file !="." and file !=".."
	            	if file.end_with?('.framework')
	            		lib_name = file.gsub(/\.framework/) {
				            |str| str.gsub!(/\.framework/, "")
						}

						targe_lib = iphoneos_dir + FS + file 
						iphoneos_lib = iphoneos_dir + FS + file + FS + lib_name
		            	iphonesimulator_lib = iphonesimulator_dir + FS + file + FS + lib_name

		            	`lipo -create -output #{iphoneos_lib} #{iphoneos_lib} #{iphonesimulator_lib}`
		            	`cp -R #{targe_lib} #{build_dir}`
	            	elsif file.end_with?('.a')
	            		targe_lib = build_dir + FS + file
		            	iphoneos_lib = iphoneos_dir + FS + file
		            	iphonesimulator_lib = iphonesimulator_dir + FS + file

		            	`lipo -create -output #{targe_lib} #{iphoneos_lib} #{iphonesimulator_lib}`
	            	end
	            end
	        end
	    else
			STDERR.puts "[!] iphoneos_dir[#{PODS_ROOT_DIR}#{FS}#{iphoneos_dir}] or iphonesimulator_dir[#{PODS_ROOT_DIR}#{FS}#{iphonesimulator_dir}] or is not exist.".red
	    end

		`rm -rf #{iphoneos_dir}`
		`rm -rf #{iphonesimulator_dir}`
		`rm -rf #{build_dir + FS + '*.h'}`
	end
                                                
	def PodStatic.libsNeedBuild(installer, libs)
        
        changedLibs = libs
        
        sandbox_state = installer.analysis_result.sandbox_state
        deletedList = sandbox_state.deleted
        if deletedList.size > 0
			deletedList.each do |lib|
	            if deletedList.include?(lib)
	                PodStatic.deleteLibFile(installer, lib)
	                changedLibs.delete(lib)
	            end
	        end
        end

        changedList = sandbox_state.changed
        if changedList.size > 0
			changedList.each do |lib|
	            if changedList.include?(lib)
	                PodStatic.deleteLibFile(installer, lib)
	            end
	        end
        end


		if !$_FORCE_BUILD 
			targetMap = Hash.new
			installer.pods_project.targets.each do |target|
				targetMap[target.name] = target
			end

			unchangedLibs = sandbox_state.unchanged

			if unchangedLibs.size > 0
				changedLibs = changedLibs.select { |lib|
					target = targetMap[lib]
					if target
						libName = target.product_type == PRODUCT_TYPE_FRAMEWORK ? lib + '.framework' : 'lib' + lib + '.a'
						!unchangedLibs.include?(lib) || !File.exist?(PODS_ROOT_DIR + FS + STATIC_LIBRARY_DIR + FS + lib + FS + libName)
                    else
                        Pod::UI.message "- PodStatic: Skip #{lib}"
                        $_SKIP_LIBS.push(lib)
					end
				}
			end
		end
        
		cleanLibs = changedLibs
		cleanLibs.each do |lib|
			$_SKIP_LIBS.each do |lib1|
				if lib == lib1
					changedLibs.delete(lib)
				end
			end
		end

		changedLibs
	end
    
    def PodStatic.deleteLibFile(installer, lib)
		#version = PodStatic.libVersion(installer, lib)

        # version changed, clear cache ...
        LIBS.each do |type|
            build_dir = PODS_ROOT_DIR + FS+ STATIC_LIBRARY_DIR + FS + type + FS + lib
            Pod::UI.message "- PodStatic: Cleaning dirt path, #{lib} [#{build_dir}]"
            `rm -rf #{build_dir}`
        end
    end
	
    def PodStatic.deleteLibs(installer)
		toDeleted = installer.analysis_result.podfile_state.deleted
		if toDeleted.size > 0
			Dir.chdir(PODS_ROOT_DIR){
				toDeleted.each do |lib|
					Pod::UI.message "- PodStatic: Deleting #{lib}"
					`rm -rf #{STATIC_LIBRARY_DIR + FS + lib}`
				end
			}
		end
	end
    
    def PodStatic.libVersion(installer, lib)
        version = ""
        root_specs = installer.analysis_result.specifications.map(&:root).uniq
        root_specs.sort_by(&:name).each do |spec|
            #Pod::UI.message "- PodStatic:libVersion #{spec.name} #{spec.version} "
            if spec.name == lib
                version = spec.version
            end
        end
        version
    end
    
	def PodStatic.configMapping(mappings)
		$_CONFIG_MAPPINGS = mappings
	end

	def PodStatic.forceBuild(t)
		$_FORCE_BUILD = t
	end

	def PodStatic.enableStaticLib(t)
		$_ENABLE_STATIC_LIB = t
	end
	
	def PodStatic.simulatorSupport(t)
		$_SIMULATOR_SUPPORT = t
	end

	def PodStatic.autoValidArchs(t)
		$_AUTO_VALID_ARCHS = t
	end

	def PodStatic.userArchs(s)
		if s
			$_DEFAULT_ARCHS = s
		end
	end

	def PodStatic.useFrameworks(t)
		$_USE_FRAMEWORKS = t		
	end

	def PodStatic.run(installer, libs)
		if $_ENABLE_STATIC_LIB
			deleteLibs(installer)
			project = installer.pods_project
			libs = libsNeedBuild(installer, libs)
			currentArchs(project, libs)
			buildLibs(installer, libs)
			updatePodProject(project, libs)
		end
	end
end
