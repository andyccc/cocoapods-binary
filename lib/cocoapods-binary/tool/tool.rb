# attr_accessor for class variable.
# usage:
#
#   ```
#   class Pod
#       class_attr_accessor :is_prebuild_stage
#   end
#   ```
#
def class_attr_accessor(symbol)
    self.class.send(:attr_accessor, symbol)
end

def Logger(tag, name, value)
    Pod::UI.puts "🚀  Prebuild --Logger-- #{tag}, #{name}:#{value}"
end

def rsync_file(type, spath, dpath)
    begin
        ret = `rsync -az #{spath} #{dpath}`
        
        Pod::UI.puts "📡  #{type} rsync => #{spath}, #{dpath}, #{ret}"

        if ret.empty?
            return true
        end
        rescue
        return false
    end
    
    return false
end

def zip_file(spath, dpath, file_name)
    Pod::UI.puts "📥  Zipper file => #{spath}, #{dpath}, #{file_name}"
    
    `cd #{spath} && zip -qr #{dpath} #{file_name}`
end

def unzip_file(spath, dpath)
    Pod::UI.puts "📤  Unzip file => #{spath}, #{dpath}"

    `unzip -oq #{spath} -d #{dpath}`
end
