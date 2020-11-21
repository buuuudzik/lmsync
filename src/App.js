import React from "react";
import "./App.css";
import { downloadBackup, parseResponse } from "./utilities";
import UploaderBackup from "./components/UI/UploaderBackup/UploaderBackup";

class App extends React.Component {
  constructor(props) {
    super(props);

    this.alertTimeoutId = null;

    this.state = {
      loading: false,
      loadingCause: false,
      alert: null,
      policies: {
        newObject: "create", // "create" || "omit"
        notExisting: "let", // "let" || "delete"
        name: "replace", // "replace" || "let" Could crash some scripts
        value: "useLater", // "replace" || "let"
        datatype: "replace", // "replace" || "let"
        comment: "let", // "replace" || "let"
        enums: "let", // "replace" || "let"
        visparams: "let", // "replace" || "let"
        tags: "concat", // "replace" || "concat" || "let"
      },
    };
  }

  changeLoading = (loading = false, loadingCause = "") => {
    this.setState({ loading, loadingCause });
  };

  getAlertColor = (alertType = "normal") => {
    const defaultColor = "#333";
    switch (alertType) {
      case "normal":
        return defaultColor;
      case "success":
        return "darkseagreen";
      case "error":
        return "#fd7b7b";
      default:
        return defaultColor;
    }
  };

  alert = (title, message, type, timeout = 5000) => {
    clearTimeout(this.alertTimeoutId);
    this.setState({ alert: { title, message, type } });
    this.alertTimeoutId = setTimeout(() => {
      this.setState({ alert: null });
    }, timeout);
  };

  getPoliciesParams = () => {
    return new URLSearchParams(this.state.policies).toString();
  };

  fetchData = () => {
    this.syncFromServer();
  };

  uploadData = (change) => {
    const config = {
      todos: this.state.todos,
      warnings: this.state.warnings,
      logs: this.state.logs,
      ...change,
    };
    this.syncToServer(config);
  };

  closeApp = () => {
    window.location = "/apps/";
  };

  changePolicy = (key, value) => {
    console.log({ key, value });
    this.setState({
      policies: { ...this.state.policies, [key]: value },
    });
  };

  createPolicyCheckbox = (key, checkedValue, uncheckedValue) => {
    return (
      <input
        type="checkbox"
        onChange={(e) => {
          const newValue = e.target.checked ? checkedValue : uncheckedValue;
          this.changePolicy(key, newValue);
        }}
        checked={this.state.policies[key] === checkedValue ? true : false}
      />
    );
  };

  render() {
    const { alert, loading, loadingCause } = this.state;
    return (
      <div className="App">
        {loading ? (
          <div className="loading">
            <div className="loading-text">
              {loadingCause ? loadingCause : "Loading..."}
            </div>
          </div>
        ) : null}
        {this.state.alert ? (
          <div
            className="alert"
            style={{ backgroundColor: this.getAlertColor(alert.type) }}
          >
            <div className="alert-title">{alert.title}</div>
            <div className="alert-message">{alert.message}</div>
            <div className="alert-buttons">
              <div
                className="alert-button"
                onClick={() => this.setState({ alert: null })}
              >
                Close
              </div>
            </div>
          </div>
        ) : null}
        <header className="App-header">
          <div className="app-title">LM Sync</div>
          <div className="header-buttons">
            <div className="close-app" onClick={this.closeApp}>
              <i className="fa fa-window-close"></i>
            </div>
          </div>
        </header>
        <div className="container">
          <div className="backup">
            <div className="backup-section">
              <div className="backup-header">Download backup</div>
              <button
                className="download-backup"
                onClick={async () => {
                  this.changeLoading(true, "Downloading backup...");
                  downloadBackup((succeed, err, response) => {
                    this.changeLoading();
                    if (!succeed) {
                      this.alert(
                        "Download failed",
                        `This is probably the reason:\n${parseResponse(
                          response
                        )}`,
                        "error"
                      );
                    }
                  });
                }}
              >
                Download
              </button>
              <a id="downloadBackup" style={{ display: "none" }}></a>
            </div>
            <div className="backup-section">
              <div className="backup-header">Restore from file</div>
              <div className="backup-options">
                <div className="backup-option">
                  <div>
                    <div>Create new objects?</div>
                    {this.createPolicyCheckbox("newObject", "create", "omit")}
                  </div>
                </div>
                <div className="backup-option">
                  <div>
                    <div>Delete not in backup?</div>
                    {this.createPolicyCheckbox("notExisting", "delete", "let")}
                  </div>
                </div>
                <div className="backup-option">
                  <div>
                    <div>Update names?</div>
                    {this.createPolicyCheckbox("name", "replace", "let")}
                  </div>
                </div>
                <div className="backup-option">
                  <div>
                    <div>Use later values?</div>
                    {this.createPolicyCheckbox("value", "useLater", "let")}
                  </div>
                </div>
                <div className="backup-option">
                  <div>
                    <div>Update tags?</div>
                    <div className="backup-option-variant">
                      <div>Concat</div>
                      <input
                        type="radio"
                        name="tags"
                        onChange={() => this.changePolicy("tags", "concat")}
                        checked={this.state.policies.tags === "concat"}
                      />
                    </div>
                    <div className="backup-option-variant">
                      <div>Replace</div>
                      <input
                        type="radio"
                        name="tags"
                        onChange={() => this.changePolicy("tags", "replace")}
                        checked={this.state.policies.tags === "replace"}
                      />
                    </div>
                    <div className="backup-option-variant">
                      <div>Omit</div>
                      <input
                        type="radio"
                        name="tags"
                        onChange={() => this.changePolicy("tags", "omit")}
                        checked={this.state.policies.tags === "omit"}
                      />
                    </div>
                  </div>
                </div>
                <div className="backup-option">
                  <div>
                    <div>Update datatype?</div>
                    {this.createPolicyCheckbox("datatype", "replace", "let")}
                  </div>
                </div>
                <div className="backup-option">
                  <div>
                    <div>Update comment?</div>
                    {this.createPolicyCheckbox("comment", "replace", "let")}
                  </div>
                </div>
                <div className="backup-option">
                  <div>
                    <div>Update enums?</div>
                    {this.createPolicyCheckbox("enums", "replace", "let")}
                  </div>
                </div>
                <div className="backup-option">
                  <div>
                    <div>Update visparams?</div>
                    {this.createPolicyCheckbox("visparams", "replace", "let")}
                  </div>
                </div>
              </div>
              <UploaderBackup
                url={`backup.lp?${this.getPoliciesParams()}`}
                refresh={(err) => {
                  this.changeLoading();
                  if (err)
                    this.alert(
                      "Upload failed",
                      `This is probably the reason:\n${err}`,
                      "error"
                    );
                  else this.alert("Upload succeed", "", "success");
                }}
                onSubmit={() => {
                  this.changeLoading(true, "Uploading backup...");
                }}
              />
            </div>
          </div>
        </div>
      </div>
    );
  }
}

export default App;
