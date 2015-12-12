
require 'uri'
require 'fileutils'
require 'git'
require 'yaml'
require 'yaml/store'
require 'digest/sha1'
require 'id3lib'
require 'highline/import'
require 'net/http'
require 'thefox-ext'

module TheFox
	module MBrew
		class MBrew
			
			def initialize(working_dir = '.')
				puts "working_dir org: '#{working_dir}'"
				
				working_dir ||= '.'
				
				puts "working_dir alt: '#{working_dir}'"
				
				@working_dir = File.realpath(working_dir)
				@working_dir_pn = Pathname.new(@working_dir)
				puts "working_dir:  '#{@working_dir}'"
				
				@dotmbrew_dir = "#{@working_dir}/.mbrew"
				puts "dotmbrew_dir: '#{@dotmbrew_dir}'"
				@is_a_mbrew_lib = Dir.exist?(@dotmbrew_dir)
				
				@config_path = "#{@dotmbrew_dir}/config.yml"
				puts "config path:  '#{@config_path}'"
				@config = nil
				if @is_a_mbrew_lib && File.exist?(@config_path)
					@config = YAML.load_file(@config_path)
				end
				
				# puts "working_dir: '#{@working_dir}'"
				# puts "config: '#{@config}'"
			end
			
			def clone(url, dir = nil)
				url = URI(url)
				dir = dir ||
					"#{url.host} #{url.path}"
						.gsub('.', '-')
						.gsub('/', ' ')
						.strip
						.gsub(/ +/, '-')
				
				puts "url: '#{url}'"
				puts "dir: '#{dir}'"
				
				url_index = "#{url}/index"
				url_index_git = "#{url_index}/.git"
				
				if !Dir.exist?(dir)
					puts "Cloning into library '#{dir}'..."
					
					Dir.mkdir(dir)
					Dir.chdir(dir) do
						Dir.mkdir('.mbrew')
						Dir.chdir('.mbrew') do
							grepo = Git.clone(url_index_git, 'index')
							grepo.config('user.name', 'Mr. Robot')
							grepo.config('user.email', 'robot@example.com')
							
							config_yml = YAML::Store.new('config.yml')
							config_yml.transaction do
								config_yml['mbrew'] = {
									'release_id' => TheFox::MBrew::RELEASE_ID,
									'version' => TheFox::MBrew::VERSION,
								}
								config_yml['origin'] = {
									'downstream' => "#{url}",
									'upstream' => nil,
								}
							end
							
							installed_yml = YAML::Store.new('installed.yml')
							installed_yml.transaction do
								installed_yml['artists'] = []
							end
						end
					end
				else
					raise "Directory '#{dir}' already exist."
				end
			end
			
			def init(dir = '.')
				Dir.chdir(dir) do
					if !Dir.exist?('.mbrew')
						Dir.mkdir('.mbrew', 0700)
						Dir.chdir('.mbrew') do
							Dir.mkdir('data')
							Dir.mkdir('bin')
							Dir.mkdir('index')
							
							Dir.chdir('bin') do
								File.open('push', 'w') do |file|
									file.chmod(0755)
									
									file.puts('#!/usr/bin/env bash')
									file.puts
									file.puts('SCRIPT_BASEDIR=$(dirname $0)')
									file.puts('RSYNC_BIN="rsync"')
									file.puts('RSYNC_OPTIONS="-vucr --delete --delete-excluded -h --progress --exclude=.DS_Store"')
									file.puts('RSYNC_REMOTE="user@remote:/path/to/public"')
									file.puts
									file.puts
									file.puts('cd $SCRIPT_BASEDIR/..')
									file.puts
									file.puts('# $RSYNC_BIN $RSYNC_OPTIONS index data $RSYNC_REMOTE')
								end
							end
							
							Dir.chdir('index') do
								grepo = Git.init('.')
								grepo.config('user.name', 'Mr. Robot')
								grepo.config('user.email', 'robot@example.com')
								
								File.write('.gitkeep', 'keep')
								grepo.add('.gitkeep')
								
								grepo.commit('Initial commit.')
							end
							
							config_yml = YAML::Store.new('config.yml')
							config_yml.transaction do
								config_yml['mbrew'] = {
									'release_id' => TheFox::MBrew::RELEASE_ID,
									'version' => TheFox::MBrew::VERSION,
								}
								config_yml['origin'] = {
									'downstream' => nil,
									'upstream' => nil,
								}
							end
						end
					else
						raise "Directory '#{dir}' is already a mbrew library."
					end
				end
			end
			
			def push
				
			end
			
			def add(paths, recursive = false)
				check_is_a_mbrew_lib
				check_staged_file
				
				file_pattern = '*.mp3'
				file_pattern = File.join('**', '*.mp3') if recursive
				
				files_staged = []
				Dir.chdir(@working_dir) do
					Dir.chdir('.mbrew') do
						files_staged = YAML.load_file('staged.yml')['files']
					end
				end
				
				paths.each do |path|
					if File.exist?(path)
						if File.directory?(path)
							Dir.glob(File.join(path, file_pattern)).sort.each do |file_path|
								real_path = File.realpath(file_path)
								files_staged << real_path
								
								puts "Adding file '#{file_path}'."
							end
						else
							real_path = File.realpath(path)
							files_staged << real_path
							
							puts "Adding file '#{path}'."
						end
					else
						$stderr.puts "WARNING: '#{path}' no such file or directory."
					end
				end
				
				files_staged.sort!.uniq!
				
				Dir.chdir(@working_dir) do
					Dir.chdir('.mbrew') do
						staged_yml = YAML::Store.new('staged.yml')
						staged_yml.transaction do
							staged_yml['files'] = files_staged
						end
					end
				end
			end
			
			def commit
				check_is_a_mbrew_lib
				check_staged_file
				
				Dir.chdir(@working_dir) do
					Dir.chdir('.mbrew') do
						grepo = Git.open('index')
						grepo.config('user.name', 'Mr. Robot')
						grepo.config('user.email', 'robot@example.com')
						
						files_staged = YAML.load_file('staged.yml')['files']
						if files_staged.count >= 0
							files_staged.each do |src_file_path|
								if File.exist?(src_file_path)
									
									src_file_relative_path = Pathname.new(src_file_path).relative_path_from(@working_dir_pn).to_s
									src_file_relative_dir = File.dirname(src_file_relative_path)
									src_file_basename = File.basename(src_file_path)
									src_file_basename_hex = Digest::SHA256.hexdigest(src_file_basename)
									src_file_relative_path_hex = Digest::SHA256.hexdigest(src_file_relative_path)
									clone_file_basename = "#{src_file_basename_hex}.mp3"
									clone_file_path = "data/#{clone_file_basename}"
									
									FileUtils.cp(src_file_path, clone_file_path)
									
									src_file_content_hex = Digest::SHA256.file(clone_file_path).hexdigest
									
									dst_dir_path = "#{src_file_relative_path_hex[0..1]}/#{src_file_relative_path_hex[2..3]}/#{src_file_relative_path_hex[4..5]}"
									dst_file_name = src_file_relative_path_hex[6..-1]
									gpg_file_name = "#{dst_file_name}.gpg"
									gpg_file_path = "#{dst_dir_path}/#{gpg_file_name}"
									yml_file_name = "#{dst_file_name}.yml"
									yml_file_path = "#{dst_dir_path}/#{yml_file_name}"
									gpg_exec = "LC_ALL=C gpg --no-tty --batch --passphrase supersecret2015 --cipher-algo AES256 -c -o '#{gpg_file_name}' '#{clone_file_basename}'"
									
									puts "src_file_path:                '#{src_file_path}'"
									puts "src_file_relative_path:       '#{src_file_relative_path}'"
									puts "src_file_relative_path_hex:   '#{src_file_relative_path_hex}'"
									puts "src_file_relative_dir:        '#{src_file_relative_dir}'"
									
									puts "src_file_basename:            '#{src_file_basename}'"
									puts "src_file_basename_hex:        '#{src_file_basename_hex}'"
									
									puts "clone_file_basename:          '#{clone_file_basename}'"
									puts "clone_file_path:              '#{clone_file_path}'"
									puts
									puts "src_file_content_hex:         '#{src_file_content_hex}'"
									puts "dst_dir_path:                 '#{dst_dir_path}'"
									puts "dst_file_name:                '#{dst_file_name}'"
									puts "gpg_file_name:                '#{gpg_file_name}'"
									puts "gpg_file_path:                '#{gpg_file_path}'"
									puts "yml_file_name:                '#{yml_file_name}'"
									puts "yml_file_path:                '#{yml_file_path}'"
									puts
									puts "gpg_exec: '#{gpg_exec}'"
									puts
									
									mp3_tag = nil
									
									Dir.chdir('data') do
										FileUtils.mkdir_p(dst_dir_path) if !Dir.exist?(dst_dir_path)
										FileUtils.rm(gpg_file_path) if File.exist?(gpg_file_path)
										
										if !File.exist?(gpg_file_path)
											FileUtils.mv(clone_file_basename, dst_dir_path)
											Dir.chdir(dst_dir_path) do
												if !system(gpg_exec).nil?
													mp3_tag = ID3Lib::Tag.new(clone_file_basename)
													FileUtils.rm(clone_file_basename)
												else
													FileUtils.rm(clone_file_basename)
													raise 'FATAL ERROR: gpg failed.'
												end
											end
										else
											FileUtils.rm(clone_file_basename)
											raise "FATAL ERROR: '#{gpg_file_path}' file already exist."
										end
									end
									
									if !mp3_tag.nil?
										Dir.chdir('index') do
											FileUtils.mkdir_p(dst_dir_path) if !Dir.exist?(dst_dir_path)
											
											mp3_tag_artist = mp3_tag.artist.to_s.to_utf8
											mp3_tag_band = mp3_tag.band.to_s.to_utf8
											mp3_tag_composer = mp3_tag.composer.to_s.to_utf8
											mp3_tag_album = mp3_tag.album.to_s.to_utf8
											mp3_tag_title = mp3_tag.title.to_s.to_utf8
											mp3_tag_year = mp3_tag.year.to_s.to_utf8
											
											
											
											yml = YAML::Store.new(yml_file_path)
											yml.transaction do
												yml['src'] = {
													'file' => {
														'path' => src_file_relative_path,
														'path_hash' => src_file_relative_path_hex,
														'name' => src_file_basename,
														'dir' => src_file_relative_dir,
														'content_hash' => src_file_content_hex,
													},
												}
												yml['id3'] = {
													'artist' => mp3_tag_artist,
													'band' => mp3_tag_band,
													'composer' => mp3_tag_composer,
													'album' => mp3_tag_album,
													'title' => mp3_tag_title,
													'year' => mp3_tag_year,
												}
											end
											
											# puts "composer: '#{mp3_tag_composer}'"
											# puts "album:    '#{mp3_tag_album}'"
											
											puts "Committing file '#{src_file_relative_path}'."
											puts "\t'#{mp3_tag_artist}' - '#{mp3_tag_title}'"
											
											begin
												grepo.add(yml_file_path)
												grepo.commit("Yml file: '#{yml_file_path}' ('#{mp3_tag_artist}' - '#{mp3_tag_title}')")
											rescue Exception => e
											end
										end
									end
								else
									$stderr.puts "WARNING: '#{file_path}' no such file."
								end
							end
						end
						
						Dir.chdir('index') do
							begin
								grepo.add('.')
								grepo.commit('Misc changes.')
							rescue Exception => e
							end
							
							system('git update-server-info')
						end
						
						staged_yml = YAML::Store.new('staged.yml')
						staged_yml.transaction do
							staged_yml['files'] = []
						end
					end
				end
			end
			
			def status
				check_is_a_mbrew_lib
				check_staged_file
				
				cwd = Dir.pwd
				cwd_pn = Pathname.new(cwd)
				
				Dir.chdir(@working_dir) do
					Dir.chdir('.mbrew') do
						files_staged = YAML.load_file('staged.yml')['files']
						if files_staged.count > 0
							paths_s = files_staged
								.map{ |p| Pathname.new(p).relative_path_from(cwd_pn).to_s }
								.join("\n\t")
							
							puts "Files staged for commit: #{files_staged.count}"
							puts
							puts Rainbow("\t" + (paths_s)).red
							puts
						end
						
						Dir.chdir('index') do
							# grepo = Git.open('.')
							# grepo.config('user.name', 'Mr. Robot')
							# grepo.config('user.email', 'robot@example.com')
							# grepo.update_server_info
							
							system('git update-server-info')
						end
					end
				end
			end
			
			def list(files = false)
				check_is_a_mbrew_lib
				
				Dir.chdir(@working_dir) do
					Dir.chdir('.mbrew/index') do
						if files
							Dir.glob('**/*.yml').map{ |yml_file_path|
								yml = YAML.load_file(yml_file_path)
								yml['src']['file']['path']
							}.sort
						else
							Dir.glob('**/*.yml').map{ |yml_file_path|
								yml = YAML.load_file(yml_file_path)
								yml['id3']['artist']
							}.uniq.sort
						end
					end
				end
			end
			
			def info(artist_names = [])
				check_is_a_mbrew_lib
				
				Dir.chdir(@working_dir) do
					Dir.chdir('.mbrew/index') do
						infos = {}
						
						artist_names.each do |artist_name|
							artist_name_dc = artist_name.downcase
							artist_found = Dir.glob('**/*.yml').map{ |yml_file_path|
									yml = YAML.load_file(yml_file_path)
									yml['id3']['artist']
								}
								.keep_if{ |a| a.downcase == artist_name_dc}
								.group_by{ |a| a }
								.map{ |a,v| [a, v.count] }
								.to_h
							
							if artist_found.count >= 1
								infos[artist_name] = {
									:name => artist_found.keys.join,
									:songs => artist_found.values.join.to_i,
								}
							else
								infos[artist_name] = {
									:name => nil,
									:songs => 0,
								}
							end
						end
						
						infos
					end
				end
			end
			
			def search(artist_names = [])
				check_is_a_mbrew_lib
				
				Dir.chdir(@working_dir) do
					Dir.chdir('.mbrew/index') do
						
						found_names = []
						artist_names.each do |artist_name|
							artist_name_rx = Regexp.new(artist_name, Regexp::IGNORECASE)
							
							found_names += Dir.glob('**/*.yml').map{ |yml_file_path|
									yml = YAML.load_file(yml_file_path)
									yml['id3']['artist']
								}
								.grep(artist_name_rx)
								.uniq
						end
						
						found_names.uniq.sort
					end
				end
			end
			
			def install(artist_names)
				check_is_a_mbrew_lib
				check_installed_file
				
				Dir.chdir(@working_dir) do
					Dir.chdir('.mbrew') do
						Dir.mkdir('tmp') if !Dir.exist?('tmp')
						
						Dir.chdir('index') do
							file_paths = Dir.glob('**/*.yml')
							yml_files = file_paths
								.map{ |yml_file_path|
									yml = YAML.load_file(yml_file_path)
									[yml_file_path, {
										'path' => yml['src']['file']['path'],
										'artist' => yml['id3']['artist'],
									}]
								}
								.to_h
								.keep_if{ |yml_file_path, yml| artist_names.include?(yml['artist']) }
							
							puts "The following files will be INSTALLED (#{yml_files.count}):"
							puts
							puts yml_files.values.map{ |yml| yml['path'] }.sort
							puts
							res = ask('Do it? [Yn] ').strip.downcase
							res = 'y' if res == ''
							if res == 'y'
								install_files(yml_files.keys)
							end
						end
					end
				end
			end
			
			def uninstall(artist_names)
				check_is_a_mbrew_lib
				
				Dir.chdir(@working_dir) do
					Dir.chdir('.mbrew') do
						installed_artists = YAML.load_file('installed.yml')['artists']
						
						Dir.chdir('index') do
							file_paths = Dir.glob('**/*.yml')
							yml_files = file_paths
								.map{ |yml_file_path| YAML.load_file(yml_file_path) }
								.keep_if{ |yml| artist_names.include?(yml['id3']['artist']) }
							
							puts 'The following files will be REMOVED:'
							puts
							puts yml_files.map{ |yml| yml['src']['file']['path'] }.sort
							puts
							res = ask('Do it? [yN] ').strip.downcase
							if res == 'y'
								puts
								
								Dir.chdir('../..') do
									printf 'Deleting file ...'
									yml_files.map{ |yml| yml['src']['file']['path'] }.uniq.sort{ |d| d.length }.reverse.each do |path|
										begin
											FileUtils.rm(path)
										rescue Exception => e
											begin
												FileUtils.rm(path)
											rescue Exception => e
											end
										end
									end
									puts ' done'
									
									dirs = yml_files.map{ |yml| yml['src']['file']['dir'] }.uniq.sort{ |d| d.length }.reverse
									
									printf 'Deleting directories ...'
									dirs.each do |path|
										begin
											FileUtils.rm("#{path}/.DS_Store")
										rescue Exception => e
										end
										
										FileUtils.rmdir(path)
									end
									puts ' done'
									
								end
								
								installed_artists -= yml_files.map{ |yml| yml['id3']['artist'] }.uniq
							end
						end
						
						printf 'Update index ...'
						installed_yml = YAML::Store.new('installed.yml')
						installed_yml.transaction do
							installed_yml['artists'] = installed_artists.uniq
						end
						puts ' done'
					end
				end
			end
			
			def update
				check_is_a_mbrew_lib
				
				Dir.chdir(@working_dir) do
					Dir.chdir('.mbrew/index') do
						printf 'Index update ...'
						grepo = Git.open('.')
						grepo.pull
						puts ' done'
					end
				end
			end
			
			def upgrade
				check_is_a_mbrew_lib
				
				Dir.chdir(@working_dir) do
					Dir.chdir('.mbrew') do
						
						installed_artists = YAML.load_file('installed.yml')['artists']
						
						Dir.chdir('index') do
							file_paths = Dir.glob('**/*.yml')
							yml_files = file_paths
								.map{ |yml_file_path|
									yml = YAML.load_file(yml_file_path)
									[yml_file_path, {
										'path' => yml['src']['file']['path'],
										'artist' => yml['id3']['artist'],
									}]
								}
								.to_h
								.keep_if{ |yml_file_path, yml| installed_artists.include?(yml['artist']) }
								.keep_if{ |yml_file_path, yml|
									Dir.chdir('../..') do
										!File.exist?(yml['path'])
									end
								}
							
							if yml_files.count > 0
								puts "The following files will be INSTALLED (#{yml_files.count}):"
								puts
								puts yml_files.values.map{ |yml| yml['path'] }.sort
								puts
								res = ask('Do it? [Yn] ').strip.downcase
								res = 'y' if res == ''
								if res == 'y'
									install_files(yml_files.keys)
								end
							else
								puts 'No new files.'
							end
							
						end
					end
				end
			end
			
			private
			
			def check_is_a_mbrew_lib
				puts "check working dir: #{@working_dir}"
				raise 'Not a mbrew library.' if !@is_a_mbrew_lib
			end
			
			def check_staged_file
				Dir.chdir(@working_dir) do
					Dir.chdir('.mbrew') do
						if !File.exist?('staged.yml')
							staged_yml = YAML::Store.new('staged.yml')
							staged_yml.transaction do
								staged_yml['files'] = []
							end
						end
					end
				end
			end
			
			def check_installed_file
				if @is_a_mbrew_lib
					Dir.chdir(@working_dir) do
						Dir.chdir('.mbrew') do
							if !File.exist?('installed.yml')
								installed_yml = YAML::Store.new('installed.yml')
								installed_yml.transaction do
									installed_yml['artists'] = []
								end
							end
						end
					end
				end
			end
			
			def install_files(file_paths)
				check_is_a_mbrew_lib
				check_installed_file
				
				downstream_url = @config['origin']['downstream']
				downstream_data_url = "#{downstream_url}/data"
				
				#p file_paths
				
				Dir.chdir(@working_dir) do
					Dir.chdir('.mbrew') do
						installed_artists = YAML.load_file('installed.yml')['artists']
						
						yml_files = []
						Dir.chdir('index') do
							yml_files = file_paths
								.map{ |yml_file_path| YAML.load_file(yml_file_path) }
						end
						
						Dir.mkdir('tmp') if !Dir.exist?('tmp')
						Dir.chdir('tmp') do
							Dir.mkdir('install') if !Dir.exist?('install')
							Dir.chdir('install') do
								
								yml_files.each do |yml|
									src_file_relative_path = yml['src']['file']['path']
									src_file_relative_path_hex = yml['src']['file']['path_hash']
									src_file_content_hex = yml['src']['file']['content_hash']
									src_file_basename = yml['src']['file']['name']
									
									dst_dir_path = "#{src_file_relative_path_hex[0..1]}/#{src_file_relative_path_hex[2..3]}/#{src_file_relative_path_hex[4..5]}"
									dst_file_name = src_file_relative_path_hex[6..-1]
									
									gpg_file_name = "#{dst_file_name}.gpg"
									gpg_file_path = "#{dst_dir_path}/#{gpg_file_name}"
									gpg_file_url = "#{downstream_data_url}/#{gpg_file_path}"
									tmp_mp3_file_name = "#{src_file_relative_path_hex}.mp3"
									
									puts "src_file_basename:     '#{src_file_basename}'"
									
									puts "gpg_file_name: '#{gpg_file_name}'"
									puts "gpg_file_path: '#{gpg_file_path}'"
									puts "gpg_file_url:  '#{gpg_file_url}'"
									
									printf "Downloading '#{src_file_relative_path}' ..."
									if !File.exist?(gpg_file_name)
										gpg_file_uri = URI(gpg_file_url)
										Net::HTTP.start(gpg_file_uri.host, gpg_file_uri.port) do |http|
											request = Net::HTTP::Get.new(gpg_file_uri)
											http.request(request) do |response|
												open(gpg_file_name, 'w') do |io|
													response.read_body do |chunk|
														io.write(chunk)
														printf '.'
													end
												end
											end
										end
									end
									puts ' done'
									
									gpg_exec = "LC_ALL=C gpg --no-tty --batch --passphrase supersecret2015 -d -o #{tmp_mp3_file_name} #{gpg_file_name}"
									puts "gpg_exec: '#{gpg_exec}'"
									
									if !system(gpg_exec).nil?
										tmp_file_content_hex = Digest::SHA256.file(tmp_mp3_file_name).hexdigest
										puts "tmp_file_content_hex:  '#{tmp_file_content_hex}'"
										puts "src_file_content_hex:  '#{src_file_content_hex}'"
										
										if src_file_content_hex == tmp_file_content_hex
											puts Rainbow('Hash OK.').green
										else
											puts Rainbow('Hash INVALID.').red
										end
										puts
										
										FileUtils.rm(gpg_file_name)
									else
										FileUtils.rm(gpg_file_name)
										raise 'FATAL ERROR: gpg failed.'
									end
								end
								
								puts 'Installing files ...'
								yml_files.each do |yml|
									src_file_relative_path = yml['src']['file']['path']
									src_file_relative_dir = yml['src']['file']['dir']
									src_file_relative_path_hex = yml['src']['file']['path_hash']
									tmp_mp3_file_name = "#{src_file_relative_path_hex}.mp3"
									
									puts src_file_relative_path
									# p Dir.pwd
									# puts "src_file_relative_path: '#{src_file_relative_path}'"
									# puts "src_file_relative_dir:  '#{src_file_relative_dir}'"
									# puts "tmp_mp3_file_name:      '#{tmp_mp3_file_name}'"
									
									Dir.chdir('../../..') do
										FileUtils.mkdir_p(src_file_relative_dir) if !Dir.exist?(src_file_relative_dir)
									end
									FileUtils.mv(tmp_mp3_file_name, "../../../#{src_file_relative_path}")
									
									installed_artists << yml['id3']['artist']
								end
							end
						end
						
						installed_yml = YAML::Store.new('installed.yml')
						installed_yml.transaction do
							installed_yml['artists'] = installed_artists.uniq
						end
					end
				end
				
			end
			
		end
	end
end
