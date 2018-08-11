extern crate iron;
extern crate router;
extern crate urlencoded;

#[macro_use] extern crate mime;

use router::Router;
use urlencoded::UrlEncodedBody;
use std::str::FromStr;
use iron::prelude::*;
use iron::status;

fn main() {
    let mut router = Router::new();

    router.get("/", get_form, "root");
    router.post("/gcd", post_gcd, "gcd");

    println!("Servinc on http://localhost:3000...");
    Iron::new(router).http("localhost:3000").unwrap();
}

fn gcd(n: u64, m: u64) -> u64 {
    if m == 0 {
        n
    } else if m > n {
        gcd(n, m % n)
    }
    else {
        gcd(m, n % m)
    }
}


fn post_gcd(request: &mut Request) -> IronResult<Response> {
    let mut response = Response::new();

    println!("Request accepted: POST");
    let form_data = match request.get_ref::<UrlEncodedBody>() {
        Err(e) => {
            response.set_mut(status::BadRequest);
            response.set_mut(format!("Error parsing form data: {:?}\n", e));
            return Ok(response);
        }
        Ok(map) => map
    };

    let unparsed_numbers = match form_data.get("n") {
        None => {
            response.set_mut(status::BadRequest);
            response.set_mut(format!("form daa has no 'parameter\n'"));
            return Ok(response);
        }
        Some(nums) => nums
    };

    let mut numbers = vec![];
    for unparsed in unparsed_numbers {
        match u64::from_str(&unparsed) {
            Err(_) => {
                response.set_mut(status::BadRequest);
                response.set_mut(
                    format!("Value for 'n' parameter not a number: {:?}\n",
                            unparsed));
                return Ok(response);
            }
            Ok(n) => { numbers.push(n); }
        }
    }

    let mut numbers = Vec::new();
    for unparsed in unparsed_numbers {
        match u64::from_str(&unparsed) {
            Err(_) => {
                response.set_mut(status::BadRequest);
                response.set_mut(
                    format!("Value for 'n' parameter not number {:?}\n",
                            unparsed));
                return Ok(response);
            }
            Ok(n) => { numbers.push(n); }
        }
    }

    let mut d = numbers[0];
    for m in &numbers[1..] {
        d = gcd(d, *m);
    }

    response.set_mut(status::Ok);
    response.set_mut(mime!(Text/Html; Charset=Utf8));
    response.set_mut(
        format!("The greates common divisor of the numbers {:?} is <b>{}</b>\n",
                numbers, d));

    Ok(response)
}


fn get_form(_request: &mut Request) -> IronResult<Response> {
    println!("Request accepted: GET");

    let mut response = Response::new();

    response.set_mut(status::Ok);
    response.set_mut(mime!(Text/Html; Charset=Utf8));
    response.set_mut(r#"
        <title>GCD Calculater</title>
        <form action="/gcd" method="POST">
            <input type="text" name="n"/>
            <input type="text" name="n"/>
            <button type="submit">Compute GCD</button>
        </form>
    "#);

    Ok(response)
}
