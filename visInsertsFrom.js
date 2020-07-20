const fs = require("fs");
const floorsCSV = fs.readFileSync("visfloors.csv", "utf8");
const objectsCSV = fs.readFileSync("./visobjects.csv", "utf8");

const correctFloorType = (floorKey, value) => {
  const intKeys = [
    "id",
    "building",
    "layout",
    "sortorder",
    "bgrepeat",
    "bgfixed",
    "width",
    "height",
    "locx",
    "locy",
    "pincode",
  ];

  if (intKeys.includes(floorKey)) {
    return +value;
  } else {
    if (floorKey === type && value === "") return null;
    return value;
  }
};

const correctObjectType = (objectKey, value) => {
  const intKeys = [
    "id",
    "floor",
    "type",
    "sortorder",
    "object",
    "statusobject",
    "locx",
    "locy",
    "readonly",
    "notouch",
    "nobg",
  ];

  if (intKeys.includes(objectKey)) {
    return +value;
  } else return value;
};

const csv2sql = (csv, tableName, columnsSeparator = ",") => {
  const rows = csv
    .trim()
    .split("\n")
    .map((r) => r.trim().split(columnsSeparator));
  const header = rows.shift();
  const insert = `INSERT INTO ${tableName} (${header
    .map((k) => `\"${k}\"`)
    .join(", ")}) VALUES \n`;
  console.log({ header });
  const res = [];
  rows.forEach((cells, i) => {
    cells.forEach((cell, j) => {
      const key = header[j];
      if (tableName === "visfloors") {
        cells[j] = correctFloorType(key, cell);
      } else if (tableName === "visobjects") {
        cells[j] = correctObjectType(key, cell);
      }
    });
    res.push(
      `(${cells
        .map((c) => {
          if (typeof c === "string") {
            return `\'${c}\'`;
          } else if (c === null) {
            return "NULL";
          } else return c;
        })
        .join(", ")})`
    );
  });
  if (res.length > 0) {
    return insert + res.join(",\n");
  }
  return "";
};

const result = {
  objects: csv2sql(objectsCSV, "visobjects", ";"),
  floors: csv2sql(floorsCSV, "visfloors"),
};

// correctFloorsTypes(result.floors);
// correctObjectsTypes(result.objects);

// console.log(`${result.floors.length} pięter`);
// console.log(`${result.objects.length} obiektów`);

fs.writeFileSync("LM_LB_visfloors.sql", result.floors, "utf8");
fs.writeFileSync("LM_LB_visobjects.sql", result.objects, "utf8");
