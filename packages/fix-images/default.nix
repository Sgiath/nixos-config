{
  lib,
  writeShellScriptBin,
  parallel-full,
  exiftool,
}:
writeShellScriptBin "fix-images" ''
  find . -type f \( \
    -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \
    -o -iname "*.tif" -o -iname "*.tiff" -o -iname "*.webp" -o -iname "*.heic" \
    -o -iname "*.heif" \) -print0 | \
  ${lib.getExe parallel-full} -0 --eta \
    ${lib.getExe exiftool} -quiet -api PNGEarlyXMP=1 -JUMBF:all= -overwrite_original {}
''
