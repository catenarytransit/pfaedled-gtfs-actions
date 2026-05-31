use clap::Parser;
use reqwest::Client;
use serde_json::json;
use std::env;
use std::process::ExitCode;

#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    /// Test the Discord webhook by sending a message even if all sites are up
    #[arg(long)]
    test: bool,
}

#[tokio::main]
async fn main() -> ExitCode {
    let args = Args::parse();
    
    let sites = [
        "https://catenarymaps.org",
        "https://birch.catenarymaps.org",
        "https://tipo.catenarymaps.org",
        "https://spruce.catenarymaps.org",
    ];

    let client = Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build()
        .unwrap();

    let mut failed_sites = Vec::new();
    let mut success_sites = Vec::new();

    for site in sites {
        let start = std::time::Instant::now();
        let res = client.get(site).send().await;
        let duration = start.elapsed();
        match res {
            Ok(response) => {
                if response.status() != 200 {
                    failed_sites.push((site, format!("HTTP {}", response.status().as_u16())));
                } else {
                    success_sites.push((site, duration));
                }
            }
            Err(e) => {
                failed_sites.push((site, format!("Error: {}", e)));
            }
        }
    }

    if failed_sites.is_empty() && !args.test {
        println!("All sites are up!");
        return ExitCode::SUCCESS;
    }

    let webhook_url = match env::var("DISCORD_WEBHOOK_URL") {
        Ok(url) => url,
        Err(_) => {
            eprintln!("DISCORD_WEBHOOK_URL environment variable not set.");
            return ExitCode::FAILURE;
        }
    };

    let user_ids_to_ping = vec![
        "204371573799518208", // specified ping
    ];

    let mentions = user_ids_to_ping
        .iter()
        .map(|id| format!("<@{}>", id))
        .collect::<Vec<_>>()
        .join(" ");

    let title = if args.test {
        "🚨 Test Alert: Uptime Checker"
    } else {
        "🚨 Sites are unreachable or unhealthy"
    };

    let description = if args.test {
        let mut desc = "This is a test alert.\n\nSites responding with 200:\n".to_string();
        for (site, duration) in &success_sites {
            desc.push_str(&format!("`{}` - {}ms\n", site, duration.as_millis()));
        }
        if !failed_sites.is_empty() {
            desc.push_str("\nFailed sites:\n");
            for (site, err) in &failed_sites {
                desc.push_str(&format!("`{}` - {}\n", site, err));
            }
        }
        desc
    } else {
        let mut desc = String::new();
        for (site, err) in &failed_sites {
            desc.push_str(&format!("`{}` - {}\n", site, err));
        }
        desc
    };

    let payload = json!({
        "content": mentions,
        "allowed_mentions": {
            "users": user_ids_to_ping
        },
        "embeds": [
            {
                "title": title,
                "description": description,
                "color": 15158332,
            }
        ]
    });

    let res = client.post(&webhook_url).json(&payload).send().await;
    match res {
        Ok(response) => {
            if response.status().is_success() {
                println!("Discord alert sent successfully.");
            } else {
                eprintln!("Failed to send Discord alert: {}", response.status());
            }
        }
        Err(e) => {
            eprintln!("Error sending Discord alert: {}", e);
        }
    }

    if !failed_sites.is_empty() {
        ExitCode::FAILURE
    } else {
        ExitCode::SUCCESS
    }
}
