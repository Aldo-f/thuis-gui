/**
 * This file is loaded via the <script> tag in the index.html file and will
 * be executed in the renderer process for that window. No Node.js APIs are
 * available in this process because `nodeIntegration` is turned off and
 * `contextIsolation` is turned on. Use the contextBridge API in `preload.js`
 * to expose Node.js functionality from the main process.
 */

document.addEventListener("DOMContentLoaded", () => {
  const mpdUrlInput = document.getElementById("mpdUrl");
  const runBatchButton = document.getElementById("runBatch");
  const downloadButton = document.getElementById("downloadButton"); // Adjust the ID accordingly

  // Set the default value for the input field
  mpdUrlInput.value = "";

  // Listen for the button click
  runBatchButton.addEventListener("click", () => {
    const mpdUrl = mpdUrlInput.value;
    electronApi.ipcRenderer.send("run-batch", mpdUrl);
  });

  electronApi.ipcRenderer.on("batch-complete", (event, result) => {
    console.log("Batch complete:", result);

    if (result.file) {
      // Show the download button
      downloadButton.style.display = "block";

      // Remove any existing click event listener
      downloadButton.removeEventListener("click", handleDownloadClick);

      // Add the new click event listener
      downloadButton.addEventListener("click", () =>
        handleDownloadClick(result)
      );
    }
  });
});

// Click handler to download resulting file
const handleDownloadClick = (result) => {
  console.log(`Download file: ${result.file}`);
  electronApi.ipcRenderer.send("show-save-dialog", result.file);
};

