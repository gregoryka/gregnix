{
  open =
    let
      archiveExtensions = [
        "7z"
        "ace"
        "ar"
        "arc"
        "bz2"
        "cab"
        "cpio"
        "cpt"
        "deb"
        "dgc"
        "dmg"
        "gz"
        "iso"
        "jar"
        "msi"
        "pkg"
        "rar"
        "rpm"
        "shar"
        "tar"
        "tgz"
        "xar"
        "xpi"
        "xz"
        "zip"
      ];

      generateArchiveRule = ext: {
        url = "*.${ext}";
        use = [
          "extract"
          "reveal"
        ];
      };

      archiveRules = map generateArchiveRule archiveExtensions;

      mediaExtensions = [
        "pdf"
        "jpg"
        "jpeg"
        "png"
        "gif"
        "webp"
        "svg"
        "bmp"
        "mp4"
        "mov"
        "mkv"
        "avi"
        "mp3"
        "wav"
        "flac"
      ];

      generateMediaRule = ext: {
        url = "*.${ext}";
        use = [
          "open"
          "reveal"
        ];
      };

      mediaRules = map generateMediaRule mediaExtensions;
    in
    {
      prepend_rules =
        archiveRules
        ++ mediaRules
        ++ [
          {
            url = "*/";
            use = [
              "edit"
              "open"
              "reveal"
            ];
          }
        ];

      append_rules = [
        {
          url = "*";
          use = [
            "edit"
            "open"
            "reveal"
          ];
        }
      ];
    };
}
