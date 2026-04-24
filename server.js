const express = require("express");
const app = express();

app.get("/", (req, res) => {
  res.send("Hello from Kubernetes App V1");
});

app.listen(process.env.PORT || 3001, "0.0.0.0", () => {
  console.log("Server running on port 3000");
});
