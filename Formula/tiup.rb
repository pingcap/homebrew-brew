class Tiup < Formula
  desc "TiDB is a MySQL compatible distributed database, and tiup is a component manager for testing and using TiDB locally."
  homepage "https://www.pingcap.com"
  url "https://tiup-mirrors.pingcap.com/install.sh"
  sha256 "2784762fa6151539ecae3a975c21996036f4d7c82a4efe1f57dbefd1579c4b98"
  license "Apache-2.0"
  version "1.7.0"

  # depends_on "go" => :build
  depends_on "curl" => :build
  depends_on "mysql-client" => :optional

  def install
    # get current user
    user = `whoami`
    user.delete!("\n")
    user.delete!("\r\n")

    # home root path
    root_ptah = if OS.mac?
      "Users"
    else
      "/home"
    end

    home_path = root_ptah+"/"+user
    # set real home path
    if user == "root"
      home_path = "/root"
    end

    # set HOME for tiup
    ENV["HOME"] = home_path
    #system "echo $HOME"

    # cretae tiup home directory
    tiup_home = home_path+"/"+".tiup"
    # install
    system "sh install.sh"

    # set tiup bin
    bin_path = tiup_home+"/bin/tiup"
    bin.install bin_path

    #system "echo 'Installed path: ", tiup_home ,"'"
  end

  def upgrade
    o = <<~EOS
      Update all installed components to the latest version
      ===============================================
        Have a try:     tiup update --all
      ===============================================

      Questions? https://docs.pingcap.com/tidb/stable/tiup-component-management

    EOS
    
  end

  def caveats
    s = <<~EOS
      To get started running a full TiDB Platform stack, with TiDB Server, TiKV Server, and PD, use tiup playground:
      ===============================================
        Have a try:     tiup playground
      ===============================================

      Questions? https://docs.pingcap.com/tidb/stable/tiup-component-management

    EOS
    s
  end

  test do
    # `test do` will create, run in and delete a temporary directory.
    #
    # This test will fail and we won't accept that! For Homebrew/homebrew-core
    # this will need to be a test that verifies the functionality of the
    # software. Run the test with `brew test tiup`. Options passed
    # to `brew install` such as `--HEAD` also need to be provided to `brew test`.
    #
    # The installed folder is not in the path, so use the entire path to any
    # executables being tested: `system "#{bin}/program", "do", "something"`.
    system "tiup" "--version"
  end
end
