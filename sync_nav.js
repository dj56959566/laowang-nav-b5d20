const https = require('https');
const fs = require('fs');
const path = require('path');

const MENUS_URL = 'https://nav.eooce.com/api/menus';
const CARDS_API_BASE = 'https://nav.eooce.com/api/cards';

// Helper function to fetch data from a URL
function fetchData(url) {
    return new Promise((resolve, reject) => {
        https.get(url, (res) => {
            let data = '';
            res.on('data', (chunk) => data += chunk);
            res.on('end', () => {
                try {
                    if (res.statusCode !== 200) {
                        reject(new Error(`Request failed with status code ${res.statusCode}`));
                        return;
                    }
                    const json = JSON.parse(data);
                    resolve(json);
                } catch (e) {
                    reject(e);
                }
            });
        }).on('error', (err) => reject(err));
    });
}

async function sync() {
    try {
        console.log('Starting synchronization...');

        // 1. Fetch Menus
        console.log(`Fetching menus from ${MENUS_URL}...`);
        const menus = await fetchData(MENUS_URL);

        // Save menus.json
        fs.writeFileSync('menus.json', JSON.stringify(menus, null, 2));
        console.log('Saved menus.json');

        const navData = [];

        // 2. Iterate through menus and fetch cards
        for (const menu of menus) {
            if (menu.subMenus && menu.subMenus.length > 0) {
                // Handle submenus
                for (const subMenu of menu.subMenus) {
                    const url = `${CARDS_API_BASE}/${menu.id}?subMenuId=${subMenu.id}`;
                    console.log(`Fetching cards for ${menu.name} - ${subMenu.name} (${url})...`);
                    try {
                        const cards = await fetchData(url);
                        // Construct the data structure expected by the frontend
                        // The frontend seems to expect objects with 'name' and 'items'
                        // Based on previous fetch_nav_data.js, it seems we want to flatten or structure it.
                        // Let's look at the existing nav_data.json structure again.
                        // It seems to be an array of categories.
                        // Let's assume the API returns the list of items directly.

                        navData.push({
                            name: `${menu.name} - ${subMenu.name}`, // Composite name for uniqueness if needed, or just subMenu.name
                            // actually, looking at the original nav_data.json, it has "name" and "items".
                            // The original fetch_nav_data.js manually mapped names.
                            // Here we can use the submenu name.
                            items: cards
                        });
                    } catch (err) {
                        console.error(`Failed to fetch ${menu.name} - ${subMenu.name}:`, err.message);
                    }
                }
            } else {
                // Handle top-level menu
                const url = `${CARDS_API_BASE}/${menu.id}`;
                console.log(`Fetching cards for ${menu.name} (${url})...`);
                try {
                    const cards = await fetchData(url);
                    navData.push({
                        name: menu.name,
                        items: cards
                    });
                } catch (err) {
                    console.error(`Failed to fetch ${menu.name}:`, err.message);
                }
            }
        }

        // 3. Save nav_data.json
        fs.writeFileSync('nav_data.json', JSON.stringify(navData, null, 2));
        console.log('Saved nav_data.json');
        console.log('Synchronization complete!');

    } catch (error) {
        console.error('Synchronization failed:', error);
    }
}

sync();
