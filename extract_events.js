const fs = require("fs");
const path = require("path");

// List of facet names
const facets = [
  "SharedFacet",
  "ProtocolFacet",
  "LiquidityPoolFacet",
  "CcipFacet",
  "DiamondLoupeFacet",
  "OwnershipFacet",
  "DiamondCutFacet",
  "GettersFacet",
];

// Function to extract events from ABI
function extractEvents(abi) {
  return abi.filter((item) => item.type === "event");
}

// Function to read ABI file
function readAbiFile(facetName) {
  const abiPath = path.join("out", `${facetName}.sol`, `${facetName}.json`);

  if (!fs.existsSync(abiPath)) {
    console.log(`ABI file not found for ${facetName}: ${abiPath}`);
    return [];
  }

  try {
    const abiContent = fs.readFileSync(abiPath, "utf8");
    const abiData = JSON.parse(abiContent);
    return abiData.abi || [];
  } catch (error) {
    console.error(`Error reading ABI for ${facetName}:`, error.message);
    return [];
  }
}

// Main function to combine all events
function combineEvents() {
  const allEvents = [];
  const eventNames = new Set(); // To avoid duplicates

  console.log("Extracting events from facet ABIs...\n");

  facets.forEach((facetName) => {
    console.log(`Processing ${facetName}...`);
    const abi = readAbiFile(facetName);
    const events = extractEvents(abi);

    console.log(`  Found ${events.length} events`);

    events.forEach((event) => {
      if (!eventNames.has(event.name)) {
        eventNames.add(event.name);
        allEvents.push(event);
        console.log(`    - ${event.name}`);
      } else {
        console.log(`    - ${event.name} (duplicate, skipping)`);
      }
    });

    console.log("");
  });

  // Create combined ABI with only events
  const combinedAbi = {
    name: "CombinedFacetEvents",
    description: "Combined events from all facets",
    events: allEvents,
  };

  // Write to file
  const outputPath = "combined_facet_events.json";
  fs.writeFileSync(outputPath, JSON.stringify(combinedAbi, null, 2));

  console.log(
    `\nCombined ${allEvents.length} unique events into ${outputPath}`
  );
  console.log("\nEvent names:");
  allEvents.forEach((event) => {
    console.log(`- ${event.name}`);
  });

  return allEvents;
}

// Run the script
if (require.main === module) {
  combineEvents();
}

module.exports = { combineEvents, extractEvents };
