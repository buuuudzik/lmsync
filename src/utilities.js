export const printDate = (unixtime = Date.now()) => {
  const dt = new Date(unixtime);
  return dt.toDateString();
};

export const parseResponse = async (response) => {
  if (response && response.status === 200) {
    try {
      const json = await response.json();
      return json;
    } catch (err) {}
    try {
      const text = await response.text();
      return text;
    } catch (err) {}
    return res.status;
  } else {
    return false;
  }
};

export const downloadBackup = async (callback) => {
  let res = null;
  try {
    res = await fetch("backup.lp");
    const backup = await res.json();
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
    callback(true);
  } catch (err) {
    callback(false, err, res);
  }
};
