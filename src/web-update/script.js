const hostname = document.querySelector("#hostname");
const version = document.querySelector("#version");
const architecture = document.querySelector("#architecture");

const form = document.querySelector("#update-form");
const file = document.querySelector("#file");
const button = document.querySelector("#upload");
const progress = document.querySelector("#progress");
const status = document.querySelector("#status");

async function loadInfo() {
  try {
    const response = await fetch("/api/info");

    if (!response.ok)
      throw new Error(`HTTP ${response.status}`);

    const info = await response.json();

    hostname.textContent = info.hostname ?? "Unknown";
    version.textContent = info.version ?? "Unknown";
    architecture.textContent = info.architecture ?? "Unknown";
  } catch (error) {
    hostname.textContent = "Unable to load appliance information";
    status.textContent = `Error: ${error.message}`;
    status.className = "error";
  }
}

form.addEventListener("submit", event => {
  event.preventDefault();

  const selected = file.files[0];

  if (!selected)
    return;

  button.disabled = true;
  file.disabled = true;

  progress.hidden = false;
  progress.value = 0;

  status.className = "";
  status.textContent = `Uploading ${selected.name}…`;

  const xhr = new XMLHttpRequest();

  xhr.upload.addEventListener("progress", event => {
    if (event.lengthComputable) {
      progress.value = event.loaded / event.total * 100;

      const percent = Math.round(progress.value);
      status.textContent = `Uploading ${selected.name}… ${percent}%`;
    }
  });

  xhr.addEventListener("load", () => {
    if (xhr.status >= 200 && xhr.status < 300) {
      progress.value = 100;
      status.textContent =
        xhr.responseText || "Update accepted. The appliance will reboot.";
      status.className = "success";
    } else {
      status.textContent =
        xhr.responseText || `Update failed (HTTP ${xhr.status}).`;
      status.className = "error";

      button.disabled = false;
      file.disabled = false;
    }
  });

  xhr.addEventListener("error", () => {
    status.textContent = "Upload failed.";
    status.className = "error";

    button.disabled = false;
    file.disabled = false;
  });

  xhr.open("POST", "/api/update");
  xhr.send(selected);
});

loadInfo();
