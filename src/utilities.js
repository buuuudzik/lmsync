export const printDate = (unixtime = Date.now()) => {
  const dt = new Date(unixtime);
  return dt.toDateString();
};

export const downloadBackup = () => {
  fetch("backup.lp")
    .then((response) => response.json())
    .then((backup) => {
      let backupString =
        "data:text/json;charset=utf-8," +
        encodeURIComponent(JSON.stringify(backup));
      let downloadBackupAnchor = document.getElementById("downloadBackup");
      downloadBackupAnchor.setAttribute("href", backupString);
      downloadBackupAnchor.setAttribute(
        "download",
        `lmsync_backup_${printDate()}.json`
      );
      downloadBackupAnchor.click();
    });
};
