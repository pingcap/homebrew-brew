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
    system "make", "tiup"
    bin.install "bin/tiup"

    # Ship the build-verified trust anchor. The operator copies it into TiUP's
    # home once: a formula cannot write there itself because post_install runs
    # sandboxed, and a shell wrapper around the binary would be bypassable
    # (libexec, `tiup update --self`) and racy.
    resource("tiup-root-json").stage do
      pkgshare.install "2.root.json" => "root.json"
    end
  end

  def caveats
    s = <<~EOS
      Install TiUP successfully!

      TiUP needs a TUF root manifest before it can talk to the mirror, and the
      first network fetch would be trusted on first use. This formula ships the
      pinned copy; install it once, verifying it again before the copy:

        mkdir -p ~/.tiup/bin
        echo "#{TUF_ROOT_SHA256}  #{opt_pkgshare}/root.json" | shasum -a 256 -c
        cp #{opt_pkgshare}/root.json ~/.tiup/bin/root.json

      This formula pins the official mirror's TUF root. A private mirror has a
      different root and needs its own formula with the matching pinned hash.

      Questions? https://docs.pingcap.com/tidb/stable/tiup-component-management

    EOS
    s
  end

  test do
    system "#{bin}/tiup" "-v"
  end
end
