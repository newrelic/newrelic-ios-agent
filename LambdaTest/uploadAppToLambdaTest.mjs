import fs from "fs";
import path from "path";
import url from "url";

import dotenv from "dotenv";
dotenv.config();

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));
const targetDir = path.resolve(__dirname, "../builds");
 
function uploadFileToLambdaTest(name, path, customId) {
  const file = fs.readFileSync(path);

  //Create body for the fetch
  const form = new FormData();
  form.append("name", name);
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
Promise.all([
  uploadFileToLambdaTest(
    "nrtestapp-iOS",
    `${targetDir}/nrtestapp-ios.zip`,
    "com.newrelic.NRApp.bitcode"
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
    }
  })
  .catch((errorMessage) => {
    console.log(errorMessage);
    process.exit(1);
  });