import fs from "node:fs";
fs.mkdirSync("/workspace/.ablab", { recursive: true });
fs.writeFileSync("/workspace/.ablab/claim.json", "{not-json");
