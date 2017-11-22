{ p ? import <nixpkgs> {} }:

let

  pkgs = import (p.fetchFromGitHub {
    owner = "nixos";
    repo = "nixpkgs";
    rev = "c19136c4c9fa1d448038023fdfedd22108a33981";
    sha256 = "1vhb0s9zv3769bv0paj2dsnqgv45g9ijj07na9qphyx3c680i4wf";
  }) {};

  inherit (pkgs) stdenv fetchurl fetchFromGitHub runCommand libxml2
    libxslt w3m remake fop jing trang imagemagick python3 dia exiftool
    ghostscript inkscape optipng xfig poppler_utils docbook_xml_dtd_45
    docbook_xml_dtd_44 docbook_xml_dtd_43 docbook_xml_dtd_42
    docbook_xml_dtd_412 docbook5 docbook5_xsl getopt docbook_xsl_ns
    which xmlstarlet bash autoreconfHook aspellWithDicts

    lib
  ;

  aspell = aspellWithDicts (dicts: [ dicts.en ]);

  daps-src = fetchFromGitHub {
    owner = "openSUSE";
    repo = "daps";
    rev = "b624f6dcf309cebee409f0d3c2fe89a9f03f7559";
    sha256 = "086bz7xfnzn7ziq0piz9wyghk81n8y4x19xp1i1nhcd00q7y6wcq";
  };

  daps-catalog = runCommand "daps-catalog" {}
    ''
      mkdir -p $out/share/xml/
      cp ${daps-src}/etc/catalog.generic $out/share/xml/catalog.xml
      cp -r ${daps-src}/daps-xslt $out/share/xml/

      substituteInPlace $out/share/xml/catalog.xml \
        --replace "../daps-xslt/" "$out/share/xml/daps-xslt/"
    '';

  svg = fetchurl {
    url = "https://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd";
    sha256 = "0kvf5bfr55flg4p5yrn5vrbph77ikl6bdrblmpysbj2d5zkrhmbl";
  };

  catalog = runCommand "catalog.xml"
    {
      buildInputs = [ libxml2 ];
      catalogs = [
        docbook5 docbook5_xsl
        docbook_xml_dtd_45 docbook_xml_dtd_44 docbook_xml_dtd_43
        docbook_xml_dtd_42 docbook_xml_dtd_412 docbook_xsl_ns

        daps-catalog
      ];
    }
    ''
      xmlcat() {
        xmlcatalog --noout "$@" "$out"
      }

     (
       echo '<?xml version="1.0"?>';
       echo '<!DOCTYPE catalog PUBLIC "-//OASIS//DTD Entity Resolution XML Catalog V1.0//EN" "http://www.oasis-open.org/committees/entity/release/1.0/catalog.dtd">';
       echo '<catalog xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog">';

      for p in $catalogs; do
        for d in $p/share/xml $p/xml/dtd $p/xml/xsl; do
          if [ -d "$d" ]; then
            for i in $(find $d -name catalog.xml); do
              echo '<nextCatalog catalog="'$i'" />';
            done
          fi
        done
      done

      echo '</catalog>'

      ) > $out

      for p in $catalogs; do
        for d in $p/share/xml $p/xml/dtd $p/xml/xsl; do
          if [ -d "$d" ]; then
            find $d -name docbookxi.rng
          fi
        done
      done

      xmlcat --add rewriteURI \
        "http://docbook.sourceforge.net/release/xsl/current/" \
        "file://${docbook5_xsl}/share/xml/docbook-xsl-ns/"

      xmlcat --add rewriteURI \
        "http://docbook.org/xml/5.0/" \
        "file://${docbook5}/share/xml/docbook-5.0/"

      xmlcat --add rewriteSystem \
        "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd" \
        "file://${svg}"
      # xmlcatalog -v $out "urn:x-daps:xslt:profiling:docbook45-profile.xsl"

      xmlcatalog -v $out "http://docbook.org/xml/5.0/rng/docbookxi.rng"

      #sleep 5
    '';
in
stdenv.mkDerivation rec {
  name = "daps-20171116";

  src = daps-src;

  buildInputs = [
    autoreconfHook
    libxml2 libxslt w3m remake fop jing trang imagemagick python3 dia
    exiftool ghostscript inkscape optipng xfig poppler_utils getopt
    which xmlstarlet aspell
  ];

  configureFlags = [
    "--enable-edit-rootcatalog=no"
  ];

  patches = [
    ./daps-init-xmlstarlet.patch
    ./daps-init-source-permissions.patch
    ./hard-coded-catalog.patch
    ./daps-path.patch
    ./tar-dont-preserve-perms.patch
  ];

  inherit xmlstarlet catalog;

  mypath = lib.makeBinPath buildInputs;

  postPatch = ''
    substituteAllInPlace ./bin/daps-init
    substituteAllInPlace ./bin/daps

    for f in "./lib/daps_functions" "./make/common_variables.mk" "./bin/daps-auto.pl"; do
      substituteInPlace "$f" \
        --replace "/bin/bash" "${bash}/bin/bash"
    done

    patchShebangs .
    for f in $(find . -type f | grep -v '.png$'); do
      substituteInPlace "$f" \
        --replace "/usr/bin/xsltproc" "${libxslt.bin}/bin/xsltproc" \
        --replace /etc/xml/catalog ${catalog} \
        --replace /usr/bin/make $(which make) \
        --replace /usr/bin/xmlstarlet ${xmlstarlet}/bin/xmlstarlet \
        --replace /usr/bin/xmlcatalog ${libxml2}/bin/xmlcatalog \
        --replace /usr/share/daps $out/share/daps \
        --replace /usr/bin/remake ${remake}/bin/remake \
        --replace /usr/bin/aspell ${aspell}/bin/aspell
    done
  '';
}
