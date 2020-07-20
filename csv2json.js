const fs = require("fs");
const objectsCSV = fs.readFileSync(
  __dirname + "/temp/lmlb_objects.csv",
  "utf8"
);
const objecttagsCSV = fs.readFileSync(
  __dirname + "/temp/lmlb_objecttags.csv",
  "utf8"
);

const csv2js = (csv) => {
  const rows = csv.split("\n").map((r) => r.trim().split(";"));
  const header = rows.shift();
  console.log({ header });
  const res = [];
  rows.forEach((cells, i) => {
    const row = {};
    cells.forEach((cell, j) => {
      const key = header[j];
      if (
        [
          "id",
          "address",
          "updatetime",
          "disablelog",
          "datatype",
          "highpriolog",
          "object",
        ].includes(key)
      ) {
        row[key] = +cell;
      } else {
        row[key] = cell;
      }
    });
    res.push(row);
  });
  return res;
};

const result = {
  objects: csv2js(objectsCSV),
  tags: csv2js(objecttagsCSV),
};

console.log(`${result.objects.length} obiektów`);
console.log(`${result.tags.length} tagów`);

fs.writeFileSync("LM_LB.json", JSON.stringify(result), "utf8");
