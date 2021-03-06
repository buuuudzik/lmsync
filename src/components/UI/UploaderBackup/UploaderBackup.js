import React, { Component } from "react";
import classes from "./UploaderBackup.css";
import { post } from "axios";

class UploaderBackup extends Component {
  state = {
    file: null,
  };

  onFormSubmit = async (e) => {
    if (this.props.onSubmit) this.props.onSubmit();
    e.preventDefault(); // Stop form submit
    try {
      const response = await this.fileUpload(this.state.file);
      if (typeof this.props.refresh === "function") {
        if (response.data.match("saved")) {
          this.props.refresh(null, response.data);
        } else {
          this.props.refresh(response.data, null);
        }
      }
      console.log(response.data);
      if (this.props.onSuccess) this.props.onSuccess();
    } catch (err) {
      if (this.props.onError) this.props.onError(err);
    }
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
