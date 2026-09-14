// Uploads a SIGNED NRTestApp .ipa to LambdaTest for REAL DEVICE testing.
//
// This is a deliberate sibling of uploadAppToLambdaTest.mjs rather than a flag on
// it, because every input and output differs and the virtual-device path is
// already green:
//
//   uploadAppToLambdaTest.mjs      this file
//   ---------------------------    ------------------------------------------
//   /app/upload/virtualDevice      /app/upload/realDevice
//   builds/nrtestapp-ios.zip       builds/nrtestapp-ios.ipa  (simulator .app
//     (an unsigned simulator         bundles cannot install on real hardware)
//      .app bundle)
//   custom_id  ...bitcode.<ts>     custom_id  ...bitcode.realdevice.<ts>
//   writes     last-app-id         writes     last-app-id-realdevice
//
// That last row is the important one: writing last-app-id here would silently
// repoint wdio-config-ios.js (the VIRTUAL run) at an .ipa it cannot install.

import fs from "fs";
import path from "path";
import url from "url";

import dotenv from "dotenv";
dotenv.config();

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));
const targetDir = path.resolve(__dirname, "../builds");
const ipaPath = `${targetDir}/nrtestapp-ios.ipa`;
const appIdFile = path.join(__dirname, "last-app-id-realdevice");

// Timestamped so a fresh upload never resolves to a cached older build, and
// namespaced with `realdevice` so it can never be confused with a virtual upload.
function generateCustomId() {
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, -5);
  return `com.newrelic.NRApp.bitcode.realdevice.${timestamp}`;
}

function uploadIpaToLambdaTest(filePath, customId) {
  const file = fs.readFileSync(filePath);

  const form = new FormData();
  form.append("name", customId);
  form.append("appFile", new File([file], path.basename(filePath)));
  form.append("visibility", "team");
  form.append("custom_id", customId);

  return fetch("https://manual-api.lambdatest.com/app/upload/realDevice", {
    method: "POST",
    headers: {
      Authorization:
        "Basic " +
        btoa(`${process.env.LT_USERNAME}:${process.env.LT_ACCESSKEY}`),
    },
    body: form,
  });
}

// Fail loudly and early. Without this the FormData build throws a bare ENOENT
// that reads like a credentials problem rather than "the archive step produced
// no .ipa".
if (!fs.existsSync(ipaPath)) {
  console.error(`Error: no signed IPA at ${ipaPath}`);
  console.error(
    "Build one with .github/workflows/uploadApp-mobile-views-2-realdevice.yml, " +
      "or export an archive locally and copy it to builds/nrtestapp-ios.ipa"
  );
  process.exit(1);
}

const customId = generateCustomId();
console.log(`Uploading ${ipaPath}`);
console.log(`Using custom_id: ${customId}`);

uploadIpaToLambdaTest(ipaPath, customId)
  .then((response) => response.json())
  .then((response) => {
    if (response.err) {
      throw new Error(
        `Error uploading IPA: ${JSON.stringify(response.err, null, 2)}`
      );
    }

    console.log("Uploaded iOS real-device asset");
    console.log(`App custom_id for tests: ${customId}`);
    console.log("\nTo run the real-device suite with this app, use:");
    console.log(`export LT_APP_ID=${customId}`);
    console.log("or");
    console.log(
      `LT_APP_ID=${customId} npx wdio LambdaTest/wdio-config-ios-realdevice.js`
    );

    fs.writeFileSync(appIdFile, customId);
    console.log(`\nApp ID saved to ${path.basename(appIdFile)}`);
  })
  .catch((errorMessage) => {
    console.log(errorMessage);
    process.exit(1);
  });
