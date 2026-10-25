class Tiup < Formula
  desc "Component manager for testing and using TiDB locally"
  homepage "https://www.pingcap.com"
  url "https://github.com/pingcap/tiup.git",
      tag:      "v1.17.1",
      revision: "63565582d33387d8a2999a86ed855bbf8fc17df9"
  license "Apache-2.0"
  version "v1.17.1"

  livecheck do
    url :stable
    strategy :git
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  # Upstream pins gopkg.in/yaml.v3 to a personal fork (github.com/WizardWuuu/yaml,
  # PR pingcap/tiup#2687) to pad float decimals. It is a pseudo-version recorded
  # in go.sum, so a rewritten fork fails the build instead of silently changing
  # code; deleting the fork breaks builds. Tracked upstream; not patched here.

  # SHA-256 of the mirror's immutable, versioned TUF root manifest.
  TUF_ROOT_SHA256 = "032201888f247db943a3ab5b84ecb5e6dbd1d77c6b9adc9657b01175cdb534bf".freeze

  depends_on "go" => :build
  # depends_on "curl" => :build
  depends_on "mysql-client" => :optional

  # TiUP bootstraps its TUF trust from this root manifest. Fetching it with curl
  # on first run is trust-on-first-use, so pin the immutable, versioned root
  # published by the mirror and verify its SHA-256 at build time instead.
  resource "tiup-root-json" do
    url "https://tiup-mirrors.pingcap.com/2.root.json"
    sha256 TUF_ROOT_SHA256
  end

  def install
    # Compile var/tiup in as the default TiUP home, so the trust anchor below is
    # exactly what TiUP reads: no wrapper, no home-directory write, no
    # trust-on-first-use download.
    system "make", "tiup",
           "EXTRA_LDFLAGS=-X github.com/pingcap/tiup/pkg/localdata.DefaultTiUPHome=#{var}/tiup"
    bin.install "bin/tiup"

    # Private home: other local users must not be able to plant or replace the
    # anchor or the components. Symlinks and foreign owners are rejected.
    home = var/"tiup"
    begin
      stat = File.lstat(home)
      unless stat.directory? && stat.uid == Process.uid
        raise "#{home} is not a directory owned by the current user"
      end
    rescue Errno::ENOENT
      home.mkpath
    end
    (home/"bin").mkpath
    home.chmod(0o700)
    (home/"bin").chmod(0o700)

    # Written at build time from the SHA-256 pinned resource above.
    resource("tiup-root-json").stage do
      (home/"bin").install "2.root.json" => "root.json"
    end
    (home/"bin/root.json").chmod(0o600)
  end

  def caveats
    s = <<~EOS
      Install TiUP successfully!

      This build of tiup uses #{var}/tiup as its home, and the pinned,
      build-verified TUF root is installed at #{var}/tiup/bin/root.json, so the
      anchor is never fetched over the network. Setting TIUP_HOME overrides that
      default and must provide its own trust root.

      This formula pins the official mirror's TUF root. A private mirror has a
      different root and needs its own formula with the matching pinned hash.

      Questions? https://docs.pingcap.com/tidb/stable/tiup-component-management

    EOS
    s
  end

  test do
    assert_predicate var/"tiup/bin/root.json", :exist?
    system "#{bin}/tiup" "-v"
  end
end
