/**
 * electron-builder configuration.
 *
 * Kept as .cjs rather than .yml because packaging decisions (signing identity,
 * notarization) have to switch on what is present in the environment, which
 * static YAML cannot express.
 */

module.exports = {
  appId: "__APP_ID__",
  productName: "__PROJECT_NAME__",

  directories: {
    output: "release",
    buildResources: "public",
  },

  // electron-vite bundles src/main (including src/main/core) into out/main,
  // so the whole app ships via the out/**/* entry — no separate copy needed.
  files: [
    "out/**/*",
    "public/**/*",
    "package.json",
    "!**/*.map",
    "!**/*.ts",
    "!**/*.tsx",
    "!**/tests/**",
  ],

  // Native modules must be unpacked so dlopen() can load the .node binary at
  // runtime — it cannot be read from inside the asar archive.
  asarUnpack: ["node_modules/better-sqlite3/**/*"],

  // Rebuild native modules against Electron's Node ABI during packaging.
  npmRebuild: true,

  mac: {
    category: "public.app-category.developer-tools",
    target: [{ target: "dmg", arch: ["arm64", "x64"] }],
    // Set MAC_IDENTITY (and APPLE_TEAM_ID for notarization) once a Developer
    // ID is provisioned. null skips signing and produces a local-only build.
    identity: process.env.MAC_IDENTITY ?? null,
    hardenedRuntime: Boolean(process.env.MAC_IDENTITY),
    gatekeeperAssess: false,
    notarize: process.env.APPLE_TEAM_ID
      ? { teamId: process.env.APPLE_TEAM_ID }
      : false,
  },

  dmg: {
    artifactName: "${productName}-${version}-${arch}.${ext}",
  },

  win: {
    target: [{ target: "nsis", arch: ["x64"] }],
    signAndEditExecutable: false,
  },

  nsis: {
    oneClick: false,
    perMachine: false,
    allowToChangeInstallationDirectory: true,
    artifactName: "${productName}-${version}-${arch}-setup.${ext}",
  },

  linux: {
    category: "Development",
    target: [{ target: "AppImage", arch: ["x64"] }],
  },

  appImage: {
    artifactName: "${productName}-${version}-${arch}.${ext}",
  },
};
