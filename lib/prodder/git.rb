module Prodder
  class Git
    GitError = Class.new(StandardError) do
      attr_reader :command, :error
      def initialize(command, error); @command, @error = command, error; end
    end

    NotFoundError = Class.new(StandardError)
    NotFastForward = Class.new(StandardError) do
      attr_reader :remote
      def initialize(remote); @remote = remote; end
    end

    def initialize(local, remote)
      @local  = local
      @remote = remote
    end

    def clone_or_remote_update
      if File.directory? File.join(@local, '.git')
        remote_update
        checkout 'master'
        reset    'origin/master', true
      else
        clone
      end
    end

    def dirty?
      inside_repo { git('status', '--porcelain') != '' }
    end

    def tracked?(file)
      inside_repo { git('ls-files', file) != '' }
    end

    def no_new_commits?
      inside_repo do
        git('show-ref', '--hash', 'origin/master') == git('show-ref', '--hash', 'refs/heads/master')
      end
    end

    def fast_forward?
      inside_repo do
        git('merge-base', 'master', 'origin/master') == git('show-ref', '--hash', 'origin/master')
      end
    end

    def clone
      git 'clone', @remote, @local
    end

    def remote_update
      inside_repo { git 'remote', 'update' }
    end

    def checkout(branch)
      inside_repo { git 'checkout', branch }
    end

    def reset(sharef, hard = false)
      inside_repo { git 'reset', hard ? '--hard' : '', sharef }
    end

    def add(file)
      inside_repo { git 'add', file }
    end

    def commit(message, author)
      inside_repo { git 'commit', "--author='#{author}'", "-m", message }
    end

    def push
      inside_repo { git 'push', 'origin', 'master:master' }
    end

    private

    def inside_repo(&block)
      Dir.chdir @local, &block
    end

    def git(*cmd, &block)
      cmd = ['git', *cmd]

      Open3.popen3(*cmd) do |stdin, out, err, thr|
        out = out.read
        err = err.read
        raise GitError.new(cmd.join(' '), err) if !thr.value.success?
        block.call(out, err, thr) if block
        out
      end
    rescue Errno::ENOENT
      raise NotFoundError
    end
  end
end
