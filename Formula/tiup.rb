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
    # install
    system "make", "tiup"
    libexec.install "bin/tiup" => "tiup"

    # Seed the pinned TUF root into TiUP's home on first use, so the trust
    # anchor is never fetched over the network (trust-on-first-use). The seed is
    # re-verified against the build-time hash before it is copied.
    (bin/"tiup").write <<~SH
      #!/bin/sh
      tiup_home="${TIUP_HOME:-$HOME/.tiup}"
      root="$tiup_home/bin/root.json"
      if [ ! -f "$root" ]; then
        src="#{opt_pkgshare}/root.json"
        actual=$(shasum -a 256 "$src" | awk '{print $1}')
        if [ "$actual" != "#{TUF_ROOT_SHA256}" ]; then
          echo "tiup: refusing to seed root.json: checksum mismatch in $src" >&2
          exit 1
        fi
        mkdir -p "$tiup_home/bin"
        cp "$src" "$root.tmp.$$"
        mv "$root.tmp.$$" "$root"
      fi
      exec "#{opt_libexec}/tiup" "$@"
    SH
    chmod 0755, bin/"tiup"

    resource("tiup-root-json").stage do
      pkgshare.install "2.root.json" => "root.json"
    end
  end

  def caveats
    s = <<~EOS
      Install TiUP successfully!

      TiUP needs a TUF root manifest. The `tiup` command seeds the pinned,
      SHA-256 verified copy into "${TIUP_HOME:-~/.tiup}/bin/root.json" on first
      use, so no trust-on-first-use download is needed.

      To use a private mirror, configure it with `tiup mirror set <url>`.
      Replacing the pinned root.json changes TiUP's trust anchor.

      Questions? https://docs.pingcap.com/tidb/stable/tiup-component-management

    EOS
    s
  end

  test do
    ENV["TIUP_HOME"] = (testpath/"tiup-home").to_s
    system bin/"tiup", "-v"
    assert_predicate testpath/"tiup-home/bin/root.json", :exist?
  end
end
