import fs from "fs";
import path from "path";
import url from "url";

import dotenv from "dotenv";
dotenv.config();

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));
const targetDir = path.resolve(__dirname, "../builds");

// Generate a unique custom_id with timestamp to avoid caching
function generateCustomId() {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5);
  return `com.newrelic.NRApp.bitcode.${timestamp}`;
}
 
function uploadFileToLambdaTest(name, path, customId) {
  const file = fs.readFileSync(path);

  //Create body for the fetch
  const form = new FormData();
  form.append("name", customId);
  form.append("appFile", new File([file], path));
  form.append("visibility", "team");
  form.append("custom_id", customId);

  //Upload the file to LT
  return fetch("https://manual-api.lambdatest.com/app/upload/virtualDevice", {
    method: "POST",
    headers: {
      Authorization:
        "Basic " +
        btoa(`${process.env.LT_USERNAME}:${process.env.LT_ACCESSKEY}`),
    },
    body: form,
  });
}
const customId = generateCustomId();
console.log(`Using custom_id: ${customId}`);

Promise.all([
  uploadFileToLambdaTest(
    "nrtestapp-iOS",
    `${targetDir}/nrtestapp-ios.zip`,
    customId
  ),
])
  .then(([iosResponse]) => //androidResponse]) =>
    Promise.all([iosResponse.json()])
  )
  .then(([iosResponse]) => {
    if (iosResponse.err) {
      throw new Error(
        `Error uploading apps: iOS: ${JSON.stringify(iosResponse.err, null, 2)}`
      );
    } else {
      console.log("Uploaded ios assets");
      console.log(`App custom_id for tests: ${customId}`);
      console.log('\nTo run tests with this app, use:');
      console.log(`export LT_APP_ID=${customId}`);
      console.log('or');
      console.log(`LT_APP_ID=${customId} npx wdio wdio-config-ios.js`);

      // Save the custom_id to a file for easy reuse
      fs.writeFileSync(path.join(__dirname, 'last-app-id'), customId);
      console.log('\nApp ID saved to last-app-id');
    }
  })
  .catch((errorMessage) => {
    console.log(errorMessage);
    process.exit(1);
  });