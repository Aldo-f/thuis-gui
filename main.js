// The main process handles Electron app lifecycle and inter-process communication
const { app, BrowserWindow, ipcMain } = require("electron");
const path = require("node:path");
const { exec } = require("child_process");

// Set NODE_ENV in the main process
process.env.NODE_ENV = app.isPackaged ? "production" : "development";

// Function to create the main window
function createWindow() {
  const mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
    },
  });

  mainWindow.loadFile("index.html");
  mainWindow.webContents.openDevTools();
}

// Listen for the 'run-batch' event from the renderer process
ipcMain.on("run-batch", (event, mpdUrl) => {
  // Modify as needed, this is where you can use the mpdUrl and execute your batch file
  const batFilePath = "thuis.bat";
  const command = `${batFilePath} ${mpdUrl}`;

  exec(command, (error, stdout, stderr) => {
    if (error) {
      console.error(`Error executing batch file: ${error.message}`);
      return;
    }

    const outputPath = stdout.trim();

    const match = outputPath.match(
      /File has been downloaded successfully to: (.*?\.mp4)/
    );

    const result = { response: outputPath, file: null };

    // Check if a match was found
    if (match && match[1]) {
      const downloadedFilePath = match[1];
      result.file = downloadedFilePath;
      console.log("Downloaded file path:", downloadedFilePath);
    } else {
      console.error("Unable to extract downloaded file path.");
    }

    event.sender.send("batch-complete", result);
  });
});

// Listen for the 'show-save-dialog' event from the renderer process
ipcMain.on("show-save-dialog", (event, filePath) => {
  const { dialog } = require("electron");

  dialog
    .showSaveDialog({
      defaultPath: filePath,
      filters: [{ name: "MP4 Files", extensions: ["mp4"] }],
    })
    .then((saveDialogResult) => {
      if (!saveDialogResult.canceled && saveDialogResult.filePath) {
        // User selected a path, do something with it
        console.log("Selected file path:", saveDialogResult.filePath);
      }
    });
});

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.whenReady().then(() => {
  createWindow();

  app.on("activate", function () {
    // On macOS it's common to re-create a window in the app when the
    // dock icon is clicked and there are no other windows open.
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

// Quit when all windows are closed, except on macOS. There, it's common
// for applications and their menu bar to stay active until the user quits
// explicitly with Cmd + Q.
app.on("window-all-closed", function () {
  if (process.platform !== "darwin") app.quit();
});

// In this file you can include the rest of your app's specific main process
// code. You can also put them in separate files and require them here.
