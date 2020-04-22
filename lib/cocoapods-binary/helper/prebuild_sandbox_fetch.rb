require_relative 'prebuild_sandbox'

module Pod
    class PrebuildFetch < PrebuildSandbox
        
        # such as  pod 'AFNetworking', '3.0'对应的 zip framework 名字为 AFNetworking-3.0.0.zip 。
        # TestEngineService (0.4.7)
        
        def self.zip_framework_name(target)
            return "#{target.root_spec.name}-#{target.root_spec.version}.zip"
        end
        
        # fetch remote files
        
        def self.fetch_remote_framework_for_target(target, ftp)
            framework_name = zip_framework_name(target)
            
            existed_remote_framework = self.remote_framework_names(ftp).include?(framework_name)
            
            return false unless existed_remote_framework
            
            framework_url = remote_framework_dir + framework_name
            
            begin
                zip_framework_path = ftp.get(framework_url)
                rescue
                Pod::UI.puts "Retry fetch remote fameworks"
                ftp.reset
                zip_framework_path = ftp.get(framework_url)
            end
            
            return false unless File.exist?(zip_framework_path)
            
            target_framework_path = generate_framework_path + target.name
            return true unless Dir.empty?(target_framework_path)
            
            extract_framework_path = generate_framework_path + target.name
            zf = Zipper.new(zip_framework_path, extract_framework_path)
            zf.extract()
            true
        end
        
        def self.sync_prebuild_framework_to_server(target, ftp)
            zip_framework = zip_framework_name(target)
            target_framework_path = framework_folder_path_for_target_name(target.name)
            zip_framework_path = framework_folder_path_for_target_name(zip_framework)
            
            # ftp server 已有相同 Tag 的包
            return if self.remote_framework_names(ftp).include? zip_framework
            # 本地 archive 失败
            return if !File.exist?(target_framework_path) || Dir.empty?(target_framework_path)
            
            begin
                Zipper.new(target_framework_path, zip_framework_path).write unless File.exist?(zip_framework_path)
                ftp.put(zip_framework_path, remote_framework_dir)
                remote_zip_framework_path = ftp.local_file(remote_framework_dir + zip_framework)
                FileUtils.mv zip_framework_path, remote_zip_framework_path, :force => true
                rescue
                Pod::UI.puts "ReTry To Sync Once"
                ftp.reset
                sync_prebuild_framework_to_server(target)
            end
        end
        
        def self.remote_framework_names(ftp)
            return ftp.fetch_remote_filenames("*.zip")
        end
        
        
    end
end
