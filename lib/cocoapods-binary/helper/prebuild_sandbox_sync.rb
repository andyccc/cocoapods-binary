
#def sync_prebuild_framework_to_server(target)
#    zip_framework = zip_framework_name(target)
#    target_framework_path = framework_folder_path_for_target_name(target.name)
#    zip_framework_path = framework_folder_path_for_target_name(zip_framework)
#
#    # ftp server 已有相同 Tag 的包
#    return if self.remote_framework_names.include? zip_framework
#    # 本地 archive 失败
#    return if !File.exist?(target_framework_path) || Dir.empty?(target_framework_path)
#
#    begin
#        Zipper.new(target_framework_path, zip_framework_path).write unless File.exist?(zip_framework_path)
#        self.ftp.put(zip_framework_path, remote_framework_dir)
#        remote_zip_framework_path = self.ftp.local_file(remote_framework_dir + zip_framework)
#        FileUtils.mv zip_framework_path, remote_zip_framework_path, :force => true
#    rescue
#        Pod::UI.puts "ReTry To Sync Once"
#        self.reset_ftp
#        sync_prebuild_framework_to_server(target)
#    end
#end
