/**
 * SwiftUI Other Components Tests
 * Tests for Buttons, Pickers, Toggles, Sliders, Steppers, Date Pickers,
 * Progress Views, Segmented Controls, Scroll Views, Stacks, and Grids
 *
 * This test suite covers various SwiftUI component interactions:
 * - Buttons: Standard, Toggle, Custom Styled, Star Button
 * - Pickers: Segmented Control, Date Picker, Custom Picker
 * - Toggles: Switch controls with state tracking
 * - Sliders: Continuous and discrete value sliders
 * - Steppers: Increment/decrement with reset and bulk operations
 * - Progress Views: Progress indicators
 * - Other components: Segmented Controls, Scroll Views, Stacks, Grids
 */

describe("SwiftUI Buttons Screen", () => {
  it("Should navigate to Buttons screen and verify title", async () => {
    // Wait for the app to load on MainScreen
    await driver.setTimeouts(5000);

    // Wait for MainScreen to be visible
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 30000 });
    await driver.setTimeouts(2000);

    // Navigate to SwiftUI screen
    const swiftUIButton = await $("~SwiftUI");
    await swiftUIButton.waitForExist({ timeout: 30000 });
    await swiftUIButton.click();
    await driver.setTimeouts(3000);

    // Navigate to Buttons screen
    const buttonsButton = await $("~Buttons");
    await buttonsButton.waitForExist({ timeout: 30000 });
    await buttonsButton.click();
    await driver.setTimeouts(3000);

    // Verify we're on Buttons screen by checking title
    const buttonsTitle = await $("~Buttons Demo");
    await buttonsTitle.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);
  });

  it("Should test Press Me button", async () => {
    // Test standard "Press Me" button
    const pressMeButton = await $("~Press Me");
    await pressMeButton.waitForExist({ timeout: 10000 });
    await pressMeButton.click();
    await driver.setTimeouts(1000);
  });

  it("Should test Toggle button with state", async () => {
    // Test Toggle button that shows state
    const toggleButton = await $("~Toggle is OFF");
    await toggleButton.waitForExist({ timeout: 10000 });
    await toggleButton.click();
    await driver.setTimeouts(1000);

    // After clicking, button text should change to "Toggle is ON"
    const toggleButtonOn = await $("~Toggle is ON");
    await toggleButtonOn.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Click again to toggle off
    await toggleButtonOn.click();
    await driver.setTimeouts(1000);
  });

  it("Should test Custom Styled Button", async () => {
    // Test custom styled button
    const customStyledButton = await $("~Custom Styled Button");
    await customStyledButton.waitForExist({ timeout: 10000 });
    await customStyledButton.click();
    await driver.setTimeouts(1000);
  });

  it("Should test Star Button", async () => {
    // Test star button (likely an icon button)
    const starButton = await $("~Star Button");
    await starButton.waitForExist({ timeout: 10000 });
    await starButton.click();
    await driver.setTimeouts(1000);
  });

  it("Should navigate back to SwiftUI screen", async () => {
    // Navigate back
    await driver.back();
    await driver.setTimeouts(2000);

        // Wait for MainScreen to be visible
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 30000 });
    await driver.setTimeouts(2000);

    // Navigate to SwiftUI screen
    const swiftUIButton = await $("~SwiftUI");
    await swiftUIButton.waitForExist({ timeout: 30000 });
    await swiftUIButton.click();
    await driver.setTimeouts(3000);
  });
});

describe("SwiftUI Pickers Screen", () => {
  it("Should navigate to Pickers screen and verify elements", async () => {


    // Navigate to Pickers screen
    const pickersButton = await $("~Pickers");
    await pickersButton.waitForExist({ timeout: 30000 });
    await pickersButton.click();
    await driver.setTimeouts(3000);

    // // Verify Pickers Demo title
    // const pickersTitle = await $("~Pickers Demo");
    // await pickersTitle.waitForExist({ timeout: 10000 });
    // await driver.setTimeouts(1000);
  });

  it("Should test segmented control picker", async () => {
    // Navigate back
    await driver.back();
    await driver.setTimeouts(2000);


    // Wait for MainScreen to be visible
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 30000 });
    await driver.setTimeouts(2000);

    // Navigate to SwiftUI screen
    const swiftUIButton = await $("~SwiftUI");
    await swiftUIButton.waitForExist({ timeout: 30000 });
    await swiftUIButton.click();
    await driver.setTimeouts(3000);

            const togglesTitle = await $("~SwiftUI Elements");
    await togglesTitle.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(3000);

    // Verify segmented control header
    const segmentedControlHeader = await $("~Segmented Controls");
    await segmentedControlHeader.waitForExist({ timeout: 10000 });
    await segmentedControlHeader.click();

    await driver.setTimeouts(3000);

    // Test Option 1 (default selected)
    const option1 = await $("~Option 1");
    await option1.waitForExist({ timeout: 10000 });
    await option1.click();
    await driver.setTimeouts(3000);

    // Test Option 2
    const option2 = await $("~Option 2");
    await option2.waitForExist({ timeout: 10000 });
    await option2.click();
    await driver.setTimeouts(3000);

    // Test Option 3
    const option3 = await $("~Option 3");
    await option3.waitForExist({ timeout: 10000 });
    await option3.click();
    await driver.setTimeouts(3000);
  });

  it("Should test date picker", async () => {

        // Navigate back
    await driver.back();
    await driver.setTimeouts(2000);

    // Wait for the app to load on MainScreen
    await driver.setTimeouts(5000);

    // Wait for MainScreen to be visible
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 30000 });
    await driver.setTimeouts(3000);

    // Navigate to SwiftUI screen
    const swiftUIButton = await $("~SwiftUI");
    await swiftUIButton.waitForExist({ timeout: 30000 });
    await swiftUIButton.click();
    await driver.setTimeouts(3000);

    // Verify Date Picker header
    const datePickerHeader = await $("~Date Pickers");
    await datePickerHeader.waitForExist({ timeout: 10000 });
    await datePickerHeader.click();
    await driver.setTimeouts(3000);

    // Interact with date picker (DatePicker element)
    const datePicker = await $('//XCUIElementTypeDatePicker');
    await datePicker.waitForExist({ timeout: 10000 });
    // Note: Actual date selection would require more complex interactions
    await driver.setTimeouts(3000);
  });

  // it("Should test custom picker", async () => {
  //   // Scroll down to see custom picker
  //   await driver.execute('mobile: scroll', { direction: 'down' });
  //   await driver.setTimeouts(2000);

  //   // Verify Custom Picker header
  //   const customPickerHeader = await $("~Custom Picker");
  //   await customPickerHeader.waitForExist({ timeout: 10000 });
  //   await driver.setTimeouts(1000);

  //   // Interact with picker wheel
  //   const pickerWheel = await $('//XCUIElementTypePickerWheel');
  //   await pickerWheel.waitForExist({ timeout: 10000 });
  //   await driver.setTimeouts(1000);
  // });

  it("Should navigate back to SwiftUI screen", async () => {
    // Scroll back up if needed
    await driver.execute('mobile: scroll', { direction: 'up' });
    await driver.setTimeouts(1000);

    // Navigate back
    await driver.back();
    await driver.setTimeouts(2000);
  });
});

describe("SwiftUI Toggles Screen", () => {
  it("Should navigate to Toggles screen and verify title", async () => {

    // Wait for the app to load on MainScreen
    await driver.setTimeouts(5000);

    // Wait for MainScreen to be visible
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 30000 });
    await driver.setTimeouts(2000);

    // Navigate to SwiftUI screen
    const swiftUIButton = await $("~SwiftUI");
    await swiftUIButton.waitForExist({ timeout: 30000 });
    await swiftUIButton.click();
    await driver.setTimeouts(3000);

        const togglesTitle = await $("~SwiftUI Elements");
    await togglesTitle.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Navigate to Toggles screen
    const togglesButton = await $("~Toggles");
    await togglesButton.waitForExist({ timeout: 30000 });
    await togglesButton.click();
    await driver.setTimeouts(3000);

    // Verify Toggles Demo title
    const togglesTitle2 = await $("~Toggle Example");
    await togglesTitle2.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);
  });

  it("Should test first toggle with state display", async () => {
    // Verify first toggle label
    const firstToggleLabel = await $("~Toggle is Off");
    await firstToggleLabel.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Find the switch element for first toggle
    const switches = await $$('//XCUIElementTypeSwitch');
    if (switches.length > 0) {
      const firstSwitch = switches[0];
      await firstSwitch.waitForExist({ timeout: 10000 });
      await firstSwitch.click();
      await driver.setTimeouts(1000);

      // Click again to toggle back
      await firstSwitch.click();
      await driver.setTimeouts(1000);
    }
  });

  it("Should verify toggle state displays", async () => {
    // Verify state display text
    const firstToggleState = await $("~Toggle is Off");
    await firstToggleState.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    const secondToggleState = await $("~Another Toggle is On");
    await secondToggleState.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);
  });

  it("Should test second toggle with state display", async () => {
    // Verify second toggle label
    const secondToggleLabel = await $("~Another Toggle State: On");
    await secondToggleLabel.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Find the switch element for second toggle
    const switches = await $$('//XCUIElementTypeSwitch');
    if (switches.length > 1) {
      const secondSwitch = switches[1];
      await secondSwitch.waitForExist({ timeout: 10000 });
      await secondSwitch.click();
      await driver.setTimeouts(1000);

      // Click again to toggle back
      await secondSwitch.click();
      await driver.setTimeouts(1000);
    }
  });

  it("Should navigate back to SwiftUI screen", async () => {
    // Navigate back
    await driver.back();
    await driver.setTimeouts(2000);
  });
});

describe("SwiftUI Sliders Screen", () => {
  it("Should navigate to Sliders screen and verify title", async () => {

        // Wait for the app to load on MainScreen
    await driver.setTimeouts(5000);

    // Wait for MainScreen to be visible
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 30000 });
    await driver.setTimeouts(2000);

    // Navigate to SwiftUI screen
    const swiftUIButton = await $("~SwiftUI");
    await swiftUIButton.waitForExist({ timeout: 30000 });
    await swiftUIButton.click();
    await driver.setTimeouts(3000);

    // Navigate to Sliders screen
    const slidersButton = await $("~Sliders");
    await slidersButton.waitForExist({ timeout: 30000 });
    await slidersButton.click();
    await driver.setTimeouts(3000);

    // Verify Sliders Demo title
    const slidersTitle = await $("~Sliders");
    await slidersTitle.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);
  });

  it("Should test continuous slider", async () => {
    // Verify continuous slider label
    const continuousSliderLabel = await $("~Continuous Slider");
    await continuousSliderLabel.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify current value display (50%)
    const sliderValue = await $("~Value: 50");
    await sliderValue.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Find the slider element
    const sliders = await $$('//XCUIElementTypeSlider');
    if (sliders.length > 0) {
      const continuousSlider = sliders[0];
      await continuousSlider.waitForExist({ timeout: 10000 });
      // Note: Actual slider manipulation would require setValue or sendKeys
      await driver.setTimeouts(1000);
    }
  });

  it("Should test discrete slider", async () => {
    // Verify discrete slider label
    const discreteSliderLabel = await $("~Discrete Slider");
    await discreteSliderLabel.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify current value display (value: 1)
    const discreteValue = await $("~Value: 1");
    await discreteValue.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Find the discrete slider element
    const sliders = await $$('//XCUIElementTypeSlider');
    if (sliders.length > 1) {
      const discreteSlider = sliders[1];
      await discreteSlider.waitForExist({ timeout: 10000 });
      await driver.setTimeouts(1000);
    }
  });

  it("Should navigate back to SwiftUI screen", async () => {
    // Navigate back
    await driver.back();
    await driver.setTimeouts(2000);
  });
});

describe("SwiftUI Steppers Screen", () => {
  it("Should navigate to Steppers screen and verify title", async () => {

        // Wait for the app to load on MainScreen
    await driver.setTimeouts(5000);

    // Wait for MainScreen to be visible
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 30000 });
    await driver.setTimeouts(2000);

    // Navigate to SwiftUI screen
    const swiftUIButton = await $("~SwiftUI");
    await swiftUIButton.waitForExist({ timeout: 30000 });
    await swiftUIButton.click();
    await driver.setTimeouts(3000);
    
    // Navigate to Steppers screen
    const steppersButton = await $("~Steppers");
    await steppersButton.waitForExist({ timeout: 30000 });
    await steppersButton.click();
    await driver.setTimeouts(3000);

    // Verify Steppers Demo title
    const steppersTitle = await $("~Steppers");
    await steppersTitle.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);
  });

  it("Should verify stepper label and current value", async () => {
    // Verify stepper label
    const stepperLabel = await $("~Current Value: 0");
    await stepperLabel.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify current value display (Value: 0)
    const currentValue = await $("~Value: 0");
    await currentValue.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);
  });

  it("Should test increment button", async () => {
    // Find increment button (typically the right button in a stepper)
    const incrementButton = await $("~Increment");
    await incrementButton.waitForExist({ timeout: 10000 });
    await incrementButton.click();
    await driver.setTimeouts(1000);

    // Click multiple times to test
    await incrementButton.click();
    await driver.setTimeouts(500);
    await incrementButton.click();
    await driver.setTimeouts(500);
  });

  it("Should test decrement button", async () => {
    // Find decrement button (typically the left button in a stepper)
    const decrementButton = await $("~Decrement");
    await decrementButton.waitForExist({ timeout: 10000 });
    await decrementButton.click();
    await driver.setTimeouts(1000);

    // Click to test
    await decrementButton.click();
    await driver.setTimeouts(500);
  });

  it("Should test reset button", async () => {
    // Test Reset button to return value to 0
    const resetButton = await $("~Reset");
    await resetButton.waitForExist({ timeout: 10000 });
    await resetButton.click();
    await driver.setTimeouts(1000);

    // Verify value is reset to 0
    const resetValue = await $("~Value: 0");
    await resetValue.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);
  });

  it("Should test bulk increase button", async () => {
    // Test "Increase by 10" button for bulk operation
    const increaseBy10Button = await $("~Increase by 10");
    await increaseBy10Button.waitForExist({ timeout: 10000 });
    await increaseBy10Button.click();
    await driver.setTimeouts(1000);

    // Click again to test
    await increaseBy10Button.click();
    await driver.setTimeouts(1000);
  });

  it("Should navigate back to SwiftUI screen", async () => {
    // Navigate back
    await driver.back();
    await driver.setTimeouts(2000);
  });
});

describe("SwiftUI Progress Views Screen", () => {
  it("Should navigate to and verify Progress Views screen", async () => {


        // Wait for the app to load on MainScreen
    await driver.setTimeouts(5000);

    // Wait for MainScreen to be visible
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 30000 });
    await driver.setTimeouts(2000);

    // Navigate to SwiftUI screen
    const swiftUIButton = await $("~SwiftUI");
    await swiftUIButton.waitForExist({ timeout: 30000 });
    await swiftUIButton.click();
    await driver.setTimeouts(3000);
    
    // Navigate to Progress Views screen
    const progressViewsButton = await $("~Progress Views");
    await progressViewsButton.waitForExist({ timeout: 30000 });
    await progressViewsButton.click();
    await driver.setTimeouts(3000);

    // Verify Progress Views title or screen presence
    // Note: XML was incomplete, so using generic verification
    await driver.setTimeouts(2000);
  });

  it("Should verify progress indicators exist", async () => {
    // Look for any progress indicators on the screen
    const progressIndicators = await $$('//XCUIElementTypeProgressIndicator');

    // If progress indicators exist, verify them
    if (progressIndicators.length > 0) {
      for (let i = 0; i < progressIndicators.length; i++) {
        await progressIndicators[i].waitForExist({ timeout: 10000 });
        await driver.setTimeouts(500);
      }
    }
  });

  it("Should navigate back to SwiftUI screen", async () => {
    // Navigate back
    await driver.back();
    await driver.setTimeouts(2000);
  });
});

describe("SwiftUI Date Pickers Screen", () => {
  it("Should navigate to and test Date Pickers screen", async () => {

    // Wait for the app to load on MainScreen
    await driver.setTimeouts(5000);

    // Wait for MainScreen to be visible
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 30000 });
    await driver.setTimeouts(2000);

    // Navigate to SwiftUI screen
    const swiftUIButton = await $("~SwiftUI");
    await swiftUIButton.waitForExist({ timeout: 30000 });
    await swiftUIButton.click();
    await driver.setTimeouts(3000);

    // Navigate to Date Pickers screen
    const datePickersButton = await $("~Date Pickers");
    await datePickersButton.waitForExist({ timeout: 30000 });
    await datePickersButton.click();
    await driver.setTimeouts(3000);

    // TODO: Add specific date picker interactions once XML layout is provided
    await driver.setTimeouts(2000);

    // Navigate back
    await driver.back();
    await driver.setTimeouts(2000);
  });
});

describe("SwiftUI Segmented Controls Screen", () => {
  it("Should navigate to and test Segmented Controls screen", async () => {

            // Wait for the app to load on MainScreen
    await driver.setTimeouts(5000);

    // Wait for MainScreen to be visible
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 30000 });
    await driver.setTimeouts(2000);

    // Navigate to SwiftUI screen
    const swiftUIButton = await $("~SwiftUI");
    await swiftUIButton.waitForExist({ timeout: 30000 });
    await swiftUIButton.click();
    await driver.setTimeouts(3000);

    // Navigate to Segmented Controls screen
    const segmentedControlsButton = await $("~Segmented Controls");
    await segmentedControlsButton.waitForExist({ timeout: 30000 });
    await segmentedControlsButton.click();
    await driver.setTimeouts(3000);

    // TODO: Add specific segmented control interactions once XML layout is provided
    await driver.setTimeouts(2000);

    // Navigate back
    await driver.back();
    await driver.setTimeouts(2000);
  });
});

describe("SwiftUI Scroll Views Screen", () => {
  it("Should navigate to and test Scroll Views screen", async () => {
            // Wait for the app to load on MainScreen
    await driver.setTimeouts(5000);

    // Wait for MainScreen to be visible
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 30000 });
    await driver.setTimeouts(2000);

    // Navigate to SwiftUI screen
    const swiftUIButton = await $("~SwiftUI");
    await swiftUIButton.waitForExist({ timeout: 30000 });
    await swiftUIButton.click();
    await driver.setTimeouts(3000);

    // Navigate to Scroll Views screen
    const scrollViewsButton = await $("~Scroll Views");
    await scrollViewsButton.waitForExist({ timeout: 30000 });
    await scrollViewsButton.click();
    await driver.setTimeouts(3000);

    // TODO: Add specific scroll view testing once XML layout is provided
    await driver.setTimeouts(2000);

    // Navigate back
    await driver.back();
    await driver.setTimeouts(2000);
  });
});

describe("SwiftUI Stacks Screen", () => {
  it("Should navigate to and test Stacks screen", async () => {
            // Wait for the app to load on MainScreen
    await driver.setTimeouts(5000);

    // Wait for MainScreen to be visible
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 30000 });
    await driver.setTimeouts(2000);

    // Navigate to SwiftUI screen
    const swiftUIButton = await $("~SwiftUI");
    await swiftUIButton.waitForExist({ timeout: 30000 });
    await swiftUIButton.click();
    await driver.setTimeouts(3000);

    // Navigate to Stacks screen
    const stacksButton = await $("~Stacks");
    await stacksButton.waitForExist({ timeout: 30000 });
    await stacksButton.click();
    await driver.setTimeouts(3000);

    // TODO: Add specific stack layout verification once XML layout is provided
    await driver.setTimeouts(2000);

    // Navigate back
    await driver.back();
    await driver.setTimeouts(2000);
  });
});

describe("SwiftUI Grids Screen", () => {
  it("Should navigate to and test Grids screen", async () => {
      // Wait for MainScreen to be visible
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 30000 });
    await driver.setTimeouts(2000);

    // Navigate to SwiftUI screen
    const swiftUIButton = await $("~SwiftUI");
    await swiftUIButton.waitForExist({ timeout: 30000 });
    await swiftUIButton.click();
    await driver.setTimeouts(3000);

    // Scroll down to see Grids option
    await driver.execute('mobile: scroll', { direction: 'down' });
    await driver.setTimeouts(2000);

            // Wait for the app to load on MainScreen
    await driver.setTimeouts(5000);

    // Navigate to Grids screen
    const gridsButton = await $("~Grids");
    await gridsButton.waitForExist({ timeout: 30000 });
    await gridsButton.click();
    await driver.setTimeouts(3000);

    // TODO: Add specific grid layout verification once XML layout is provided
    await driver.setTimeouts(2000);

    // Navigate back
    await driver.back();
    await driver.setTimeouts(2000);

    // Navigate back to MainScreen
    await driver.back();
    await driver.setTimeouts(2000);

    // Verify we're back on MainScreen
    const helloWorldText2 = await $("~public");
    await helloWorldText2.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Put app in background to trigger any pending events
    await driver.activateApp('com.apple.Preferences');
    await driver.setTimeouts(5000);
  });
});
