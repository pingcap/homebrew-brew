class Tiup < Formula
  desc "TiDB is a MySQL compatible distributed database, and tiup is a component manager for testing and using TiDB locally."
  homepage "https://www.pingcap.com"
  url "https://github.com/pingcap/tiup.git",
      tag:      "v1.11.1"
  license "Apache-2.0"
  version "v1.11.1"

  depends_on "go" => :build
  # depends_on "curl" => :build
  depends_on "mysql-client" => :optional

  # TiUP bootstraps its TUF trust from this root manifest. Fetching it with curl
  # on first run is trust-on-first-use, so pin the immutable, versioned root
  # published by the mirror and verify its SHA-256 at build time instead.
  resource "tiup-root-json" do
    url "https://tiup-mirrors.pingcap.com/2.root.json"
    sha256 "032201888f247db943a3ab5b84ecb5e6dbd1d77c6b9adc9657b01175cdb534bf"
  end

  def install
    # install
    system "make", "tiup"
    # set tiup bin
    bin_path = "bin/tiup"
    bin.install bin_path

    # Provide the hash-verified TUF root so no unverified first-run download is
    # needed.
    resource("tiup-root-json").stage do
      pkgshare.install "2.root.json" => "root.json"
    end
  end

  def caveats
    s = <<~EOS
      Install TiUP successfully!  Please run:
      (If you have a private mirror source, Please replace https://tiup-mirrors.pingcap.com/root.json to your private mirror source:)

      TiUP needs a TUF root manifest before it can use the mirror. This formula
      installs a pinned, SHA-256 verified copy, so do not fetch a fresh one:

      ================================================================================================================
      ! Must do:      mkdir -p ~/.tiup/bin && cp #{opt_pkgshare}/root.json ~/.tiup/bin/root.json
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
    system "#{bin}/tiup" "-v"
  end
end
