import React, { Component } from "react";
import classes from "./UploaderBackup.css";
import { post } from "axios";

class UploaderBackup extends Component {
  state = {
    file: null,
  };

  onFormSubmit = (e) => {
    e.preventDefault(); // Stop form submit
    this.fileUpload(this.state.file).then((response) => {
      if (typeof this.props.refresh === "function") {
        if (response.data.match("saved")) {
          this.props.refresh(null, response.data);
        } else {
          this.props.refresh(response.data, null);
        }
      }
      console.log(response.data);
    });
  };
  onChange = (e) => this.setState({ file: e.target.files[0] });

  fileUpload = (file) => {
    const { url } = this.props;

    const formData = new FormData();
    formData.append("request_type", "backup");
    formData.append("file", file);
    const config = {
      headers: {
        "content-type": "multipart/form-data",
      },
    };

    if (typeof this.props.parseResponse === "function")
      this.props.parseResponse(JSON.parse(file));
    return post(url, formData, config);
  };

  render() {
    return (
      <div className={classes.UploaderBackup}>
        <form className="upload-form" onSubmit={this.onFormSubmit}>
          <div className="UploadInput">
            <input
              type="file"
              accept=".json"
              name="backup"
              onChange={this.onChange}
            />
          </div>
          <div className={classes.UploadBtn}>
            <button type="submit">Upload</button>
          </div>
        </form>
      </div>
    );
  }
}

export default UploaderBackup;
