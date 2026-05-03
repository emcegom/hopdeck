import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const config = JSON.parse(readFileSync(join(root, "src-tauri", "tauri.conf.json"), "utf8"));
const productName = config.productName;
const version = config.version;
const arch = process.env.HOPDECK_RELEASE_ARCH ?? (process.arch === "arm64" ? "aarch64" : process.arch);
const tag = process.env.HOPDECK_RELEASE_TAG ?? `v${version}`;
const repository = process.env.HOPDECK_RELEASE_REPOSITORY ?? "emcegom/hopdeck";
const notes = process.env.HOPDECK_RELEASE_NOTES ?? `Hopdeck ${version}`;
const bundleDir = join(root, "src-tauri", "target", "release", "bundle", "macos");
const appPath = join(bundleDir, `${productName}.app`);
const updateBundlePath = join(bundleDir, `${productName}.app.tar.gz`);
const updateSignaturePath = `${updateBundlePath}.sig`;
const releaseDir = join(root, "release");
const zipName = `${productName}_${version}_${arch}.app.zip`;
const updateBundleName = `${productName}_${version}_${arch}.app.tar.gz`;
const zipPath = join(releaseDir, zipName);
const releaseUpdateBundlePath = join(releaseDir, updateBundleName);
const releaseUpdateSignaturePath = `${releaseUpdateBundlePath}.sig`;
const manifestPath = join(releaseDir, "latest.json");

if (!existsSync(appPath)) {
  throw new Error(`Missing app bundle: ${appPath}. Run npm run build first.`);
}

mkdirSync(releaseDir, { recursive: true });
execFileSync("ditto", ["-c", "-k", "--sequesterRsrc", "--keepParent", appPath, zipPath], {
  stdio: "inherit"
});
writeChecksum(zipPath);

if (existsSync(updateBundlePath) && existsSync(updateSignaturePath)) {
  copyFileSync(updateBundlePath, releaseUpdateBundlePath);
  copyFileSync(updateSignaturePath, releaseUpdateSignaturePath);
  writeChecksum(releaseUpdateBundlePath);

  const manifest = {
    version,
    notes,
    pub_date: new Date().toISOString(),
    platforms: {
      [`darwin-${arch}`]: {
        signature: readFileSync(releaseUpdateSignaturePath, "utf8").trim(),
        url: `https://github.com/${repository}/releases/download/${tag}/${updateBundleName}`
      }
    }
  };

  writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
  writeChecksum(manifestPath);
} else {
  console.warn("Updater bundle was not found. Run npm run build:release with TAURI_SIGNING_PRIVATE_KEY set to generate latest.json.");
}

function writeChecksum(path) {
  const checksum = execFileSync("shasum", ["-a", "256", path], { encoding: "utf8" });
  writeFileSync(`${path}.sha256`, checksum);
}
