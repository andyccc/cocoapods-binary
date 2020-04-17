

# such as  pod 'AFNetworking', '3.0'对应的 zip framework 名字为 AFNeworkings-3.0.0.zip 。

def zip_framework_name(target)
    target.pod_name + ""
end

# fetch remote files

def fetch_remote_framework_for_target(target)
    existed_remote_framework = self.remote_framework_names.include?(zip_framework_name(target))

    return false unless existed_remote_framework

    begin
        zip_framework_path = self.ftp.get(remote_framework_dir + zip_framework_name(target))
    rescue
        Pod::UI.puts "Retry fetch remote fameworks"
        self.reset_ftp
        zip_framework_path = self.ftp.get(remote_framework_dir + zip_framework_name(target))
    end

    return false unless File.exist?(zip_framework_path)

    target_framework_path = generate_framework_path + target.name
    return true unless Dir.empty?(target_framework_path)

    extract_framework_path = generate_framework_path + target.name
    zf = Zipper.new(zip_framework_path, extract_framework_path)
    zf.extract()
    true
end

