1. Create a NEW PUBLIC GitHub repo (public = free build minutes).
2. Upload everything in this folder, keeping the structure
   (project.yml, Sources/, Resources/, Assets.xcassets/, .github/workflows/build.yml).
   The .github folder is hidden on Windows - GitHub Desktop or dragging the whole
   unzipped folder onto the repo's upload page both work.
3. Open the repo's Actions tab. "Build IPA" runs automatically (~3-5 min).
4. Download the "CardReveal-ipa" artifact, unzip it to get CardReveal.ipa.
5. In iLoader, sign in with your Apple ID and install CardReveal.ipa.
6. On the iPhone: Settings > Privacy & Security > Developer Mode ON; trust the profile if asked.
If signing complains the bundle ID is taken, change PRODUCT_BUNDLE_IDENTIFIER in project.yml
to something unique and push again.
