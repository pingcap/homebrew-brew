class Tiup < Formula
  desc "TiDB is a MySQL compatible distributed database, and tiup is a component manager for testing and using TiDB locally."
  homepage "https://www.pingcap.com"
  url "https://github.com/pingcap/tiup.git",
      tag:      "v1.9.4"
  license "Apache-2.0"
  version "v1.9.4"

  depends_on "go" => :build
  # depends_on "curl" => :build
  depends_on "mysql-client" => :optional

  def install
    # install
    system "make", "tiup"
    # set tiup bin
    bin_path = "bin/tiup"
    bin.install bin_path
 
    # end
  end

  def caveats
    s = <<~EOS
      Install TiUP successfully!  Please run:
      (If you have a private mirror source, Please replace https://tiup-mirrors.pingcap.com/root.json to your private mirror source:)

      ================================================================================================================
      ! Must do:      mkdir -p ~/.tiup/bin && curl https://tiup-mirrors.pingcap.com/root.json -o ~/.tiup/bin/root.json
      ================================================================================================================

      Questions? https://docs.pingcap.com/tidb/stable/tiup-component-management

    EOS
    s
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


  test do
    # The installed folder is not in the path, so use the entire path to any
    # executables being tested: `system "#{bin}/program", "do", "something"`.
    system "#{bin}/tiup" "--version"
  end
end
