describe("Run NRTestApp - ios", () => {
  it("Opens app", async () => {
    // wait for the app to load
    await driver.setTimeouts(5000);

    const home = await $("id:Home");
    await home.waitForExist({ timeout: 30000 });
    await home.click();
    await driver.setTimeouts(5000);
  });

  // it("Opens the ToDo tab and adds todo", async () => {
  //   const todo = await $("accessibility id:TodoList");
  //   await todo.waitForExist({ timeout: 3000 });
  //   await todo.click();
  //   await driver.setTimeouts(3000);

  //   const openKeyboard = await $("accessibility id:text-input-flat");
  //   await openKeyboard.waitForExist({ timeout: 3000 });
  //   await openKeyboard.click();
  //   await driver.setTimeouts(3000);
  //   const typeS = await $("accessibility id:S");
  //   await typeS.click();
  //   await driver.setTimeouts(3000);
  //   const typeD = await $("accessibility id:d");
  //   await typeD.click();
  //   await driver.setTimeouts(3000);
  //   const typeF = await $("accessibility id:f");
  //   await typeF.click();
  //   await driver.setTimeouts(3000);
  //   const typeG = await $("accessibility id:g");
  //   await typeG.click();
  //   await driver.setTimeouts(3000);
  //   const add = await $("accessibility id:Add");
  //   await add.click();
  //   await driver.setTimeouts(3000);
  //   const closeKeyboard2 = await $("accessibility id:Return");
  //   await closeKeyboard2.click();
  //   await driver.setTimeouts(3000);
  // });

  // it("Clicks around the Explore tab", async () => {
  //   const exploreTab = await $("accessibility id:Explore");
  //   await exploreTab.waitForExist({ timeout: 30000 });
  //   await exploreTab.click();
  //   await driver.setTimeouts(5000);

  //   const googlelink = await $(
  //     '-ios class chain:**/XCUIElementTypeStaticText[`name == "Google"`][2]'
  //   );
  //   await googlelink.waitForExist({ timeout: 30000 });
  //   await googlelink.click();
  //   await driver.setTimeouts(5000);

  //   const googleTopBar = await driver.$("accessibility id:TopBrowserBar");
  //   await googleTopBar.waitForExist({ timeout: 30000 });
  //   await googleTopBar.click();
  //   await driver.setTimeouts(5000);

  //   const closeGoogle = await driver.$(
  //     '-ios class chain:**/XCUIElementTypeButton[`name == "Done"`]'
  //   );
  //   await closeGoogle.waitForExist({ timeout: 30000 });
  //   await closeGoogle.click();
  //   await driver.setTimeouts(5000);

  //   const newrelicLink = await $(
  //     '-ios class chain:**/XCUIElementTypeStaticText[`name == "New Relic"`][2]'
  //   );
  //   await newrelicLink.waitForExist({ timeout: 30000 });
  //   await newrelicLink.click();
  //   await driver.setTimeouts(5000);

  //   const NRtopBar = await driver.$("accessibility id:TopBrowserBar");
  //   await NRtopBar.waitForExist({ timeout: 30000 });
  //   await NRtopBar.click();
  //   await driver.setTimeouts(5000);

  //   const closeNR = await $(
  //     '-ios class chain:**/XCUIElementTypeButton[`name == "Done"`]'
  //   );
  //   await closeNR.waitForExist({ timeout: 30000 });
  //   await closeNR.click();
  //   await driver.setTimeouts(5000);

  //   const expoLink = await $(
  //     '-ios class chain:**/XCUIElementTypeStaticText[`name == "Expo"`][2]'
  //   );
  //   await expoLink.waitForExist({ timeout: 30000 });
  //   await expoLink.click();
  //   await driver.setTimeouts(5000);

  //   const expoTopBar = await driver.$("accessibility id:TopBrowserBar");
  //   await expoTopBar.waitForExist({ timeout: 30000 });
  //   await expoTopBar.click();
  //   await driver.setTimeouts(5000);

  //   const closeExpo = await $(
  //     '-ios class chain:**/XCUIElementTypeButton[`name == "Done"`]'
  //   );
  //   await closeExpo.waitForExist({ timeout: 30000 });
  //   await closeExpo.click();
  //   await driver.setTimeouts(5000);

  //   const hexClick = await $("accessibility id:HandledException");
  //   await hexClick.waitForExist({ timeout: 30000 });
  //   await hexClick.click();
  //   await driver.setTimeouts(5000);

  //   const goodRequest = await $("accessibility id:Good Http Request");
  //   await goodRequest.waitForExist({ timeout: 30000 });
  //   await goodRequest.click();
  //   await driver.setTimeouts(5000);

  //   const dtRequest = await driver.$(
  //     "accessibility id:Distributed Tracing Request"
  //   );
  //   await dtRequest.waitForExist({ timeout: 30000 });
  //   await dtRequest.click();
  //   await driver.setTimeouts(5000);

  //   const reset = await driver.$("accessibility id:Reset");
  //   await reset.waitForExist({ timeout: 30000 });
  //   await reset.click();
  //   await driver.setTimeouts(5000);

  //   const badRequest = await $("accessibility id:Bad Http Request");
  //   await badRequest.waitForExist({ timeout: 30000 });
  //   await badRequest.click();
  //   await driver.setTimeouts(5000);

  //   const delayedRequest = await driver.$(
  //     "accessibility id:Delayed Http Request"
  //   );
  //   await delayedRequest.waitForExist({ timeout: 30000 });
  //   await delayedRequest.click();
  //   await driver.setTimeouts(5000);

  //   await badRequest.click();
  //   await driver.setTimeouts(3000);
  //   await badRequest.click();
  //   await driver.setTimeouts(3000);
  //   await badRequest.click();
  //   await driver.setTimeouts(3000);
  //   await badRequest.click();
  //   await driver.setTimeouts(3000);
  //   await badRequest.click();
  //   await driver.setTimeouts(3000);
  //   await badRequest.click();
  //   await driver.setTimeouts(3000);
  //   await badRequest.click();
  //   await driver.setTimeouts(3000);

  //   await delayedRequest.click();
  //   await driver.setTimeouts(5000);
  //   await delayedRequest.click();
  //   await driver.setTimeouts(5000);
  //   await hexClick.click();
  //   await driver.setTimeouts(5000);

  //   await driver.executeScript("mobile:pressButton", [{ name: "home" }]);
  //   await driver.setTimeouts(5000);
  //   await driver.execute("mobile: launchApp", {
  //     bundleId: "com.newrelic.mainagenttestapp",
  //   });
  //   await driver.setTimeouts(5000);

  //   await goodRequest.click();
  //   await driver.setTimeouts(3000);
  //   await goodRequest.click();
  //   await driver.setTimeouts(3000);
  //   await goodRequest.click();
  //   await driver.setTimeouts(3000);
  //   await goodRequest.click();
  //   await driver.setTimeouts(3000);
  //   await goodRequest.click();
  //   await driver.setTimeouts(3000);
  //   await goodRequest.click();
  //   await driver.setTimeouts(3000);
  //   await hexClick.click();
  //   await driver.setTimeouts(5000);

  //   await delayedRequest.click();
  //   await driver.setTimeouts(5000);
  //   await delayedRequest.click();
  //   await driver.setTimeouts(5000);

  //   await driver.executeScript("mobile:pressButton", [{ name: "home" }]);
  //   await driver.setTimeouts(5000);
  //   await driver.execute("mobile: launchApp", {
  //     bundleId: "com.newrelic.mainagenttestapp",
  //   });
  //   await driver.setTimeouts(5000);

  //   await dtRequest.click();
  //   await driver.setTimeouts(3000);
  //   await dtRequest.click();
  //   await driver.setTimeouts(3000);
  //   await dtRequest.click();
  //   await driver.setTimeouts(3000);
  //   await dtRequest.click();
  //   await driver.setTimeouts(3000);
  //   await dtRequest.click();
  //   await driver.setTimeouts(3000);
  //   await dtRequest.click();

  //   await driver.executeScript("mobile:pressButton", [{ name: "home" }]);
  //   await driver.setTimeouts(5000);
  //   await driver.execute("mobile: launchApp", {
  //     bundleId: "com.newrelic.mainagenttestapp",
  //   });
  //   await driver.setTimeouts(5000);
  // });

  // it("Clicks around the Crash tab", async () => {
  //   const crashTab = await $("accessibility id:Crash");
  //   await crashTab.waitForExist({ timeout: 30000 });
  //   await crashTab.click();
  //   await driver.setTimeouts(5000);

  //   const uriError = await $("accessibility id:URI Error");
  //   await uriError.waitForExist({ timeout: 30000 });
  //   await uriError.click();
  //   await driver.setTimeouts(5000);

  //   await driver.execute("mobile: launchApp", {
  //     bundleId: "com.newrelic.mainagenttestapp",
  //   });
  //   await driver.setTimeouts(5000);

  //   await crashTab.waitForExist({ timeout: 30000 });
  //   await crashTab.click();
  //   await driver.setTimeouts(3000);

  //   const typeError = await $("accessibility id:Type Error");
  //   await typeError.waitForExist({ timeout: 30000 });
  //   await typeError.click();
  //   await driver.setTimeouts(5000);

  //   await driver.execute("mobile: launchApp", {
  //     bundleId: "com.newrelic.mainagenttestapp",
  //   });
  //   await driver.setTimeouts(5000);

  //   await crashTab.waitForExist({ timeout: 30000 });
  //   await crashTab.click();
  //   await driver.setTimeouts(3000);

  //   const evalError = await $("accessibility id:Eval Error");
  //   await evalError.waitForExist({ timeout: 30000 });
  //   await evalError.click();
  //   await driver.setTimeouts(5000);

  //   await driver.execute("mobile: launchApp", {
  //     bundleId: "com.newrelic.mainagenttestapp",
  //   });
  //   await driver.setTimeouts(5000);
  // });

  it("Opens app", async () => {
    // wait for the app to load
    await driver.setTimeouts(5000);

    const home = await $("id:Home");
    await home.waitForExist({ timeout: 30000 });
    await home.click();
    await driver.setTimeouts(3000);
  });
});
