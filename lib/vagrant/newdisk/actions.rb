module Vagrant
  module Newdisk
    class Action

      class NewDiskVirtualBox
        def initialize(app, env)
          @app = app
          @machine = env[:machine]
          @config = @machine.config.newdisk
          @enabled = true
          @ui = env[:ui]
          if @machine.provider.to_s !~ /VirtualBox/
            @enabled = false
            provider = @machine.provider.to_s
            env[:ui].error "The vagrant-newdisk plugin only supports VirtualBox or HyperV at present: current is #{provider}."
          end
        end

        def call(env)
          # Create the disk before boot
          if @enabled and @config.is_set?
            path = @config.path
            size = @config.size
            env[:ui].info "call virtualbox newdisk: size = #{size}, path = #{path}"

            if File.exist? path
              env[:ui].info "skip virtualbox newdisk - already exists: #{path}"
            else
              new_disk(env, path, size)
              env[:ui].success "done virtualbox newdisk: size = #{size}, path = #{path}"
            end
          end

          # Allow middleware chain to continue so VM is booted
          @app.call(env)
        end

        private

        def new_disk(env, path, size)
          driver = @machine.provider.driver
          create_disk(driver, path, size)
          attach_disk(driver, path)
        end

        def attach_disk(driver, path)
          disk = find_place_for_new_disk(driver)
          @ui.info "Attaching new disk: #{path} at #{disk}"
          driver.execute('storageattach', @machine.id, '--storagectl', disk[:controller],
                         '--port', disk[:port].to_s, '--device', disk[:device].to_s, '--type', 'hdd',
                         '--medium', path)
        end

        def find_place_for_new_disk(driver)
          disks = get_disks(driver)
          @ui.info "existing disks = #{disks.to_s}"
          controller = disks.first[:controller]
          disks = disks.select { |disk| disk[:controller] == controller }
          port = disks.map { |disk| disk[:port] }.max
          disks = disks.select { |disk| disk[:port] == port }
          max_device = disks.map { |disk| disk[:device] }.max

          {:controller => controller, :port => port.to_i, :device => max_device.to_i + 1}
        end

        def get_disks(driver)
          vminfo = get_vminfo(driver)
          disks = []
          disk_keys = vminfo.keys.select { |k| k =~ /-ImageUUID-/ }
          disk_keys.each do |key|
            uuid = vminfo[key]
            disk_name = key.gsub(/-ImageUUID-/,'-')
            parts = disk_name.split('-')
            disks << {
              controller: parts[0],
              port: parts[1].to_i,
              device: parts[2].to_i
            }
          end
          disks
        end

        def get_vminfo(driver)
          vminfo = {}
          driver.execute('showvminfo', @machine.id, '--machinereadable', retryable: true).
            split("\n").each do |line|
            parts = line.partition('=')
            key = unquoted(parts.first)
            value = unquoted(parts.last)
            vminfo[key] = value
          end
          vminfo
        end

        def create_disk(driver, path, size)
          driver.execute('createhd', '--filename', path, '--size', size.to_s)
        end

        def unquoted(s)
          s.gsub(/\A"(.*)"\Z/,'\1')
        end
      end


      class NewDiskHyperV
        def initialize(app, env)
          @app = app
          @machine = env[:machine]
          @config = @machine.config.newdisk
          @enabled = true
          @ui = env[:ui]
          if @machine.provider.to_s !~ /Hyper-V/
            @enabled = false
            provider = @machine.provider.to_s
            env[:ui].error "The vagrant-newdisk plugin only supports VirtualBox or HyperV at present: current is #{provider}."
          end
        end

        def call(env)
          # Create the disk before boot
          if @enabled and @config.is_set?
            path = @config.path
            size = @config.size
            env[:ui].info "Machine is : #{@machine}"
            env[:ui].info "call hyperv newdisk: size = #{size}, path = #{path}"

            if File.exist? path
              env[:ui].info "skip hyperv newdisk - already exists: #{path}"
            else
              if new_disk(env, path, size)
                env[:ui].success "done hyperv newdisk: size = #{size}, path = #{path}"
              end
            end

            attach_disk(env, path)
          end

          # Allow middleware chain to continue so VM is booted
          @app.call(env)
        end

        private
        
        def is_num?(str)
          !!Integer(str)
        rescue ArgumentError, TypeError
          false
        end

        def size_convert(size)
          if is_num?(size)
            # Numeric size is in MB
            return size * 1024
          end

          regex = /([0-9]+)\s?(.*)/
          hash = { 'KB' => 1024, 'MB' => 1024**2, 'GB' => 1024**3, 'TB' => 1024**4}
          m = size.match(regex)
          unless m.nil?
            @ui.info "Match: #{m} -> #{m[1]} #{m[2]}"
            if hash.include? m[2]
              return m[1].to_i*hash[m[2]]
            end
          end
          @ui.error "Invalid size syntax '#{size}''."
          return nil
        end

        def new_disk(env, path, size)
          disk_size = size_convert(size)
          if disk_size.nil?
            return false
          else
            driver = @machine.provider.driver
            options = {
              "DiskPath" => path,
              "DiskSize" => disk_size,
            }
            s = File.join(File.dirname(__FILE__), 'scripts', 'new_vhd.ps1')
            driver.execute(s, options)
            return true
          end
        end

        def attach_disk(env, path)
          driver = @machine.provider.driver
          options = {
            "VMID" => @machine.id,
            "DiskPath" => path,
          }
          s = File.join(File.dirname(__FILE__), 'scripts', 'add_vmharddiskdrive.ps1')
          cmd = s
          options.each do |key, value|
            cmd += " -#{key} #{value}"
          end

          env[:ui].info "Executing Powershell: #{cmd}"
          driver.execute(s, options)
          return true
        end
      end
	  end
  end
end
