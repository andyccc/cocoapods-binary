require_relative 'prebuild_sandbox'
require_relative '../tool/tool'
#require 'fileutils'

module Pod
    class PrebuildFetch < PrebuildSandbox
        
        # such as  pod 'AFNetworking', '3.0'对应的 zip framework 名字为 AFNetworking-3.0.0.zip 。
        # TestEngineService (0.4.7)
        
        def self.zip_framework_name(name, version)
            return "#{name}-#{version}.zip"
        end
        
        # rsync type
        
        def self.fetch_remote_framework_for_target(name, version, generate_path, rsync_server_url)

            out_path = generate_path + "/" + name
            
            zip_framework = self.zip_framework_name(name, version)
            zip_framework_path = generate_path + "/" + zip_framework
            
            framework_url = "#{rsync_server_url}/#{zip_framework}"
            
            Pod::UI.puts "☁️ Prebuilding Fetch remote fameworks, #{zip_framework}"
            
            ret = rsync_file(framework_url, zip_framework_path)
            if not ret
                Pod::UI.puts "☁️ Prebuilding Retry fetch remote fameworks, #{zip_framework}"
                FileUtils.rm_rf zip_framework_path, :verbose => true
                ret = rsync_file(framework_url, zip_framework_path)
            end
            
            return false unless ret
            return false unless File.exist?(zip_framework_path)
            return true unless Dir.empty?(out_path)
            
            unzip_file(zip_framework_path, generate_path)
            
            FileUtils.rm_rf zip_framework_path, :verbose => true
            true
        end
        
        def self.sync_prebuild_framework_to_server(name, version, generate_path, rsync_server_url)

            zip_framework = self.zip_framework_name(name, version)
            zip_framework_path = generate_path + "/" + zip_framework
            
            target_path = generate_path + "/" + name
            
            # 本地 archive 失败
            return if !File.exist?(target_path) || Dir.empty?(target_path)
            
            Pod::UI.puts "☁️ Prebuilding To Sync Once, #{zip_framework}, #{generate_path}"
            
            zip_file(generate_path, zip_framework_path, name) unless File.exist?(zip_framework_path)
            
            ret = rsync_file(zip_framework_path, rsync_server_url)
            if ret
                FileUtils.rm_rf zip_framework_path, :verbose => true
            else
                Pod::UI.puts "☁️ Prebuilding ReTry To Sync Once, #{zip_framework}, #{generate_path}"
                
                ret = rsync_file(zip_framework_path, rsync_server_url)
            end
            
            if ret
                Pod::UI.puts "☁️ Prebuilding To Sync Ok, #{zip_framework}, #{generate_path}"
            else
                Pod::UI.puts "☁️ Prebuilding To Sync Fail, #{zip_framework}, #{generate_path}"
            end
        end
        
        # ftp  unused

        def self.fetch_remote_framework_for_target_ftp(target, ftp)
            framework_name = zip_framework_name(target)
            
            existed_remote_framework = self.remote_framework_names(ftp).include?(framework_name)
            
            return false unless existed_remote_framework
            
            framework_uri = remote_framework_dir + framework_name
            
            begin
                zip_framework_path = ftp.get(framework_uri)
                rescue
                Pod::UI.puts "Retry fetch remote fameworks"
                ftp.reset
                zip_framework_path = ftp.get(framework_uri)
            end
            
            return false unless File.exist?(zip_framework_path)
            
            target_path = generate_framework_path + target.name
            return true unless Dir.empty?(target_path)
            
            extract_framework_path = generate_framework_path + target.name
            zf = Zipper.new(zip_framework_path, extract_framework_path)
            zf.extract()
            true
        end
        
        
        def self.sync_prebuild_framework_to_server_ftp(target, ftp)
            zip_framework = zip_framework_name(target)
            target_path = framework_folder_path_for_target_name(target.name)
            zip_framework_path = framework_folder_path_for_target_name(zip_framework)
            
            # ftp server 已有相同 Tag 的包
            return if self.remote_framework_names(ftp).include? zip_framework
            # 本地 archive 失败
            return if !File.exist?(target_path) || Dir.empty?(target_path)
            
            begin
                Zipper.new(target_path, zip_framework_path).write unless File.exist?(zip_framework_path)
                ftp.put(zip_framework_path, remote_framework_dir)
                remote_zip_framework_path = ftp.local_file(remote_framework_dir + zip_framework)
                FileUtils.mv zip_framework_path, remote_zip_framework_path, :force => true
                rescue
                Pod::UI.puts "ReTry To Sync Once"
                ftp.reset
                self.sync_prebuild_framework_to_server_ftp(target)
            end
        end
        
        
        def self.remote_framework_names(ftp)
            return ftp.fetch_remote_filenames("*.zip")
        end
        
        
    end
end
