require 'pod/command/repo_art'
require 'art_source'
require 'cocoapods-downloader'

Pod::HooksManager.register('cocoapods-art', :source_provider) do |context, options|
    Pod::UI.message 'cocoapods-art received source_provider hook'
    return unless (sources = options['sources'])
    sources.each do |source_name|
        source = create_source_from_name(source_name)
        if source
			# no auto-updates for now
            # update_source(source) unless Pod::Config.instance.skip_repo_update?
        else
          Pod::UI.warn "repo #{source_name} does not exist."
        end
        context.add_source(source)
    end
end

# @param [Source] source The source update
#
def update_source(source)
    name = source.name
    argv = CLAide::ARGV.new([name])
    cmd = Pod::Command::RepoArt::Update.new(argv)
    cmd.run
end

# @param source_name => name of source incoming from the Podfile configuration
#
# @return [ArtSource] source of the local spec repo which corresponds to to the given name
#
def create_source_from_name(source_name)
    repos_dir = Pod::Config.instance.repos_dir
    repo = repos_dir + source_name
    if File.exist?("#{repo}/.artpodrc")
        url = File.read("#{repo}/.artpodrc")
        Pod::ArtSource.new(repo, url)
    elsif Dir.exist?("#{repo}")
        Pod::ArtSource.new(repo, '');
    else
        nil
    end
end

#
# This ugly monkey patch is here just so we can pass the -n flag to curl and thus use the ~/.netrc file
# to manage credentials. Why this trivial option is not included in the first place is beyond me.
#
module Pod
    module Downloader
        class Http

            alias_method :orig_download_file, :download_file

            def download_file(full_filename)
                curl! '-n', '-f', '-L', '-o', full_filename, url, '--create-dirs'
            end

        end
    end
end

# Ugly, ugly hack to override pod's default behavior which is force the master spec repo if
# no sources defined - at this point the plugin sources are not yet fetched from the plugin
# with the source provider hook thus empty Podfiles that only have the plugin declared will
# force a master repo update.
module Pod
    class Installer
        class Analyzer

          alias_method :orig_sources, :sources

          def sources
            if podfile.sources.empty? && podfile.plugins.keys.include?('cocoapods-art')
              sources = Array.new
              plugin_config = podfile.plugins['cocoapods-art']
              # all sources declared in the plugin clause
              plugin_config['sources'].uniq.map do |name|
                sources.push(create_source_from_name(name))
              end
              @sources = sources
            else
              orig_sources
            end
          end

        end
    end
  end
