# Homebrew Cask für OpenClark
# Wird bei neuem Release automatisch aktualisiert.
#
# Installation:
#   brew tap nickybricks/openclark
#   brew install --cask openclark
#
# Oder direkt:
#   brew install --cask nickybricks/openclark/openclark

cask "openclark" do
  version "0.1.0"
  sha256 "TODO_SHA256_HASH"

  url "https://github.com/nickybricks/openclark/releases/download/v#{version}/OpenClark-#{version}.dmg"
  name "OpenClark"
  desc "Intelligent automatic file renaming for macOS"
  homepage "https://github.com/nickybricks/openclark"

  depends_on macos: ">= :sonoma"

  app "OpenClark.app"

  zap trash: [
    "~/.config/openclark",
    "~/.local/share/openclark",
  ]
end
