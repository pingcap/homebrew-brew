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
    # set tiup home
    tiup_home = ENV["HOME"]+"/"+".tiup"

    # install
    system "sh install.sh"

    # set tiup bin
    bin_path = tiup_home+"/bin/tiup"
    #root_path = tiup_home+"/bin/root.json"
    bin.install bin_path
    #system "echo 'Installed path: ", tiup_home ,"'"
    # end
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
      Install TiUP successfully!  Please run:
      (If you have a private mirror source, Please replace https://tiup-mirrors.pingcap.com/root.json to your private mirror source:)\

      ======================================================================
      ! Must do:      mkdir -p ~/.tiup/bin && curl https://tiup-mirrors.pingcap.com/root.json -o ~/.tiup/bin/root.json
      ======================================================================

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
