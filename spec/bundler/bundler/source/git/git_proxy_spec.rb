# frozen_string_literal: true

RSpec.describe Bundler::Source::Git::GitProxy do
  let(:path) { Pathname("path") }
  let(:uri) { "https://github.com/rubygems/rubygems.git" }
  let(:ref) { nil }
  let(:branch) { nil }
  let(:tag) { nil }
  let(:options) { { "ref" => ref, "branch" => branch, "tag" => tag }.compact }
  let(:revision) { nil }
  let(:git_source) { nil }
  let(:clone_result) { double(Process::Status, success?: true) }
  let(:base_clone_args) { ["clone", "--bare", "--no-hardlinks", "--quiet", "--no-tags", "--depth", "1", "--single-branch"] }
  subject(:git_proxy) { described_class.new(path, uri, options, revision, git_source) }

  context "with explicit ref" do
    context "with branch only" do
      let(:branch) { "main" }
      it "sets explicit ref to branch" do
        expect(git_proxy.explicit_ref).to eq(branch)
      end
    end

    context "with ref only" do
      let(:ref) { "HEAD" }
      it "sets explicit ref to ref" do
        expect(git_proxy.explicit_ref).to eq(ref)
      end
    end

    context "with tag only" do
      let(:tag) { "v1.0" }
      it "sets explicit ref to ref" do
        expect(git_proxy.explicit_ref).to eq(tag)
      end
    end

    context "with tag and branch" do
      let(:tag) { "v1.0" }
      let(:branch) { "main" }
      it "raises error" do
        expect { git_proxy }.to raise_error(Bundler::Source::Git::AmbiguousGitReference)
      end
    end

    context "with tag and ref" do
      let(:tag) { "v1.0" }
      let(:ref) { "HEAD" }
      it "raises error" do
        expect { git_proxy }.to raise_error(Bundler::Source::Git::AmbiguousGitReference)
      end
    end

    context "with branch and ref" do
      let(:branch) { "main" }
      let(:ref) { "HEAD" }
      it "honors ref over branch" do
        expect(git_proxy.explicit_ref).to eq(ref)
      end
    end
  end

  context "with configured credentials" do
    it "adds username and password to URI" do
      Bundler.settings.temporary(uri => "u:p") do
        allow(git_proxy).to receive(:git_local).with("--version").and_return("git version 2.14.0")
        expect(git_proxy).to receive(:capture).with([*base_clone_args, "--", "https://u:p@github.com/rubygems/rubygems.git", path.to_s], nil).and_return(["", "", clone_result])
        subject.checkout
      end
    end

    it "adds username and password to URI for host" do
      Bundler.settings.temporary("github.com" => "u:p") do
        allow(git_proxy).to receive(:git_local).with("--version").and_return("git version 2.14.0")
        expect(git_proxy).to receive(:capture).with([*base_clone_args, "--", "https://u:p@github.com/rubygems/rubygems.git", path.to_s], nil).and_return(["", "", clone_result])
        subject.checkout
      end
    end

    it "does not add username and password to mismatched URI" do
      Bundler.settings.temporary("https://u:p@github.com/rubygems/rubygems-mismatch.git" => "u:p") do
        allow(git_proxy).to receive(:git_local).with("--version").and_return("git version 2.14.0")
        expect(git_proxy).to receive(:capture).with([*base_clone_args, "--", uri, path.to_s], nil).and_return(["", "", clone_result])
        subject.checkout
      end
    end

    it "keeps original userinfo" do
      Bundler.settings.temporary("github.com" => "u:p") do
        original = "https://orig:info@github.com/rubygems/rubygems.git"
        git_proxy = described_class.new(Pathname("path"), original, options)
        allow(git_proxy).to receive(:git_local).with("--version").and_return("git version 2.14.0")
        expect(git_proxy).to receive(:capture).with([*base_clone_args, "--", original, path.to_s], nil).and_return(["", "", clone_result])
        git_proxy.checkout
      end
    end
  end

  describe "#version" do
    context "with a normal version number" do
      before do
        expect(git_proxy).to receive(:git_local).with("--version").
          and_return("git version 1.2.3")
      end

      it "returns the git version number" do
        expect(git_proxy.version).to eq("1.2.3")
      end

      it "does not raise an error when passed into Gem::Version.create" do
        expect { Gem::Version.create git_proxy.version }.not_to raise_error
      end
    end

    context "with a OSX version number" do
      before do
        expect(git_proxy).to receive(:git_local).with("--version").
          and_return("git version 1.2.3 (Apple Git-BS)")
      end

      it "strips out OSX specific additions in the version string" do
        expect(git_proxy.version).to eq("1.2.3")
      end

      it "does not raise an error when passed into Gem::Version.create" do
        expect { Gem::Version.create git_proxy.version }.not_to raise_error
      end
    end

    context "with a msysgit version number" do
      before do
        expect(git_proxy).to receive(:git_local).with("--version").
          and_return("git version 1.2.3.msysgit.0")
      end

      it "strips out msysgit specific additions in the version string" do
        expect(git_proxy.version).to eq("1.2.3")
      end

      it "does not raise an error when passed into Gem::Version.create" do
        expect { Gem::Version.create git_proxy.version }.not_to raise_error
      end
    end
  end

  describe "#full_version" do
    context "with a normal version number" do
      before do
        expect(git_proxy).to receive(:git_local).with("--version").
          and_return("git version 1.2.3")
      end

      it "returns the git version number" do
        expect(git_proxy.full_version).to eq("1.2.3")
      end
    end

    context "with a OSX version number" do
      before do
        expect(git_proxy).to receive(:git_local).with("--version").
          and_return("git version 1.2.3 (Apple Git-BS)")
      end

      it "does not strip out OSX specific additions in the version string" do
        expect(git_proxy.full_version).to eq("1.2.3 (Apple Git-BS)")
      end
    end

    context "with a msysgit version number" do
      before do
        expect(git_proxy).to receive(:git_local).with("--version").
          and_return("git version 1.2.3.msysgit.0")
      end

      it "does not strip out msysgit specific additions in the version string" do
        expect(git_proxy.full_version).to eq("1.2.3.msysgit.0")
      end
    end
  end

  it "doesn't allow arbitrary code execution through Gemfile uris with a leading dash" do
    gemfile <<~G
      gem "poc", git: "-u./pay:load.sh"
    G

    file = bundled_app("pay:load.sh")

    create_file file, <<~RUBY
      #!/bin/sh

      touch #{bundled_app("canary")}
    RUBY

    FileUtils.chmod("+x", file)

    bundle :lock, raise_on_error: false

    expect(Pathname.new(bundled_app("canary"))).not_to exist
  end

  context "URI is HTTP" do
    let(:uri) { "http://github.com/rubygems/rubygems.git" }
    let(:without_depth_arguments) { ["clone", "--bare", "--no-hardlinks", "--quiet", "--no-tags", "--single-branch"] }
    let(:fail_clone_result) { double(Process::Status, success?: false) }

    it "retries without --depth when git url is http and fails" do
      allow(git_proxy).to receive(:git_local).with("--version").and_return("git version 2.14.0")
      allow(git_proxy).to receive(:capture).with([*base_clone_args, "--", uri, path.to_s], nil).and_return(["", "dumb http transport does not support shallow capabilities", fail_clone_result])
      expect(git_proxy).to receive(:capture).with([*without_depth_arguments, "--", uri, path.to_s], nil).and_return(["", "", clone_result])

      subject.checkout
    end
  end

  describe "#installed_to?" do
    let(:destination) { "install/dir" }
    let(:destination_dir_exists) { true }
    let(:children) { ["gem.gemspec", "README.me", ".git", "Rakefile"] }

    before do
      allow(Dir).to receive(:exist?).with(destination).and_return(destination_dir_exists)
      allow(Dir).to receive(:children).with(destination).and_return(children)
    end

    context "when destination dir exists with children other than just .git" do
      it "returns true" do
        expect(git_proxy.installed_to?(destination)).to be true
      end
    end

    context "when destination dir does not exist" do
      let(:destination_dir_exists) { false }

      it "returns false" do
        expect(git_proxy.installed_to?(destination)).to be false
      end
    end

    context "when destination dir is empty" do
      let(:children) { [] }

      it "returns false" do
        expect(git_proxy.installed_to?(destination)).to be false
      end
    end

    context "when destination dir has only .git directory" do
      let(:children) { [".git"] }

      it "returns false" do
        expect(git_proxy.installed_to?(destination)).to be false
      end
    end
  end

  describe "#checkout" do
    context "when the repository isn't cloned" do
      before do
        allow(path).to receive(:exist?).and_return(false)
      end

      it "clones the repository" do
        allow(git_proxy).to receive(:git_local).with("--version").and_return("git version 2.14.0")
        expect(git_proxy).to receive(:capture).with([*base_clone_args, "--", uri, path.to_s], nil).and_return(["", "", clone_result])
        subject.checkout
      end
    end

    context "when the repository is cloned" do
      before do
        allow(path).to receive(:exist?).and_return(true)
      end

      context "with a locked revision" do
        let(:revision) { Digest::SHA1.hexdigest("ruby") }

        context "when the revision exists locally" do
          it "uses the cached revision" do
            allow(git_proxy).to receive(:git_local).with("--version").and_return("git version 2.14.0")
            expect(git_proxy).to receive(:git).with("cat-file", "-e", revision, dir: path).and_return(true)
            subject.checkout
          end
        end

        context "when the revision doesn't exist locally" do
          it "fetches the specific revision" do
            allow(git_proxy).to receive(:git_local).with("--version").and_return("git version 2.14.0")
            expect(git_proxy).to receive(:git).with("cat-file", "-e", revision, dir: path).and_raise(Bundler::GitError)
            expect(git_proxy).to receive(:capture).with(["fetch", "--force", "--quiet", "--no-tags", "--depth", "1", "--", uri, "#{revision}:refs/#{revision}-sha"], path).and_return(["", "", clone_result])
            subject.checkout
          end
        end
      end

      context "with no explicit ref" do
        it "fetches the HEAD revision" do
          parsed_revision = Digest::SHA1.hexdigest("ruby")
          allow(git_proxy).to receive(:git_local).with("rev-parse", "--abbrev-ref", "HEAD", dir: path).and_return(parsed_revision)
          allow(git_proxy).to receive(:git_local).with("--version").and_return("git version 2.14.0")
          expect(git_proxy).to receive(:capture).with(["fetch", "--force", "--quiet", "--no-tags", "--depth", "1", "--", uri, "refs/heads/#{parsed_revision}:refs/heads/#{parsed_revision}"], path).and_return(["", "", clone_result])
          subject.checkout
        end
      end

      context "with a commit ref" do
        let(:ref) { Digest::SHA1.hexdigest("ruby") }

        context "when the revision exists locally" do
          it "uses the cached revision" do
            allow(git_proxy).to receive(:git_local).with("--version").and_return("git version 2.14.0")
            expect(git_proxy).to receive(:git).with("cat-file", "-e", ref, dir: path).and_return(true)
            subject.checkout
          end
        end

        context "when the revision doesn't exist locally" do
          it "fetches the specific revision" do
            allow(git_proxy).to receive(:git_local).with("--version").and_return("git version 2.14.0")
            expect(git_proxy).to receive(:git).with("cat-file", "-e", ref, dir: path).and_raise(Bundler::GitError)
            expect(git_proxy).to receive(:capture).with(["fetch", "--force", "--quiet", "--no-tags", "--depth", "1", "--", uri, "#{ref}:refs/#{ref}-sha"], path).and_return(["", "", clone_result])
            subject.checkout
          end
        end
      end

      context "with a non-commit ref" do
        let(:ref) { "HEAD" }

        it "fetches all revisions" do
          allow(git_proxy).to receive(:git_local).with("--version").and_return("git version 2.14.0")
          expect(git_proxy).to receive(:capture).with(["fetch", "--force", "--quiet", "--no-tags", "--", uri, "refs/*:refs/*"], path).and_return(["", "", clone_result])
          subject.checkout
        end
      end
    end
  end
end
