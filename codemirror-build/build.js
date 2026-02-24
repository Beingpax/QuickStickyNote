const esbuild = require("esbuild");
const fs = require("fs");
const path = require("path");

const outDir = path.resolve(
  __dirname,
  "../Quick Sticky Notes/Resources/CodeMirror"
);

async function build() {
  // Bundle the editor JS
  const result = await esbuild.build({
    entryPoints: [path.join(__dirname, "src/editor.js")],
    bundle: true,
    format: "iife",
    write: false,
    minify: true,
    target: ["safari16"],
  });

  const jsCode = result.outputFiles[0].text;

  // Read the CSS
  const cssCode = fs.readFileSync(
    path.join(__dirname, "src/editor.css"),
    "utf8"
  );

  // Generate the HTML file
  const html = `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
${cssCode}
</style>
</head>
<body>
<div id="editor"></div>
<script>
${jsCode}
</script>
</body>
</html>`;

  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(path.join(outDir, "editor.html"), html);
  console.log("Built editor.html successfully");
}

build().catch((err) => {
  console.error(err);
  process.exit(1);
});
