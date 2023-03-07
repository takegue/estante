
extern crate iron;
extern crate router;
#[macro_use] extern crate mime;

use std::str::FromStr;
use std::mem;
use iron::prelude::*;
use iron::status;
use router::Router;
use urlencoded::UrlEncodedBody;


#[test]
fn test_gcd() {
    assert_eq!(gcd(14, 15), 1);
    assert_eq!(gcd(2 * 3 * 5 * 11 * 17, 3 * 7 * 11 * 19), 3 * 11);
}

fn main() {
    let mut router = Router::new();
    router.get("/", get_form, "root");
    router.post("/gcd", post_gcd, "gcd");
    println!("Serving on http://localhost:3000...");

    Iron::new(router).http("localhost:3000").unwrap();
}

fn gcd(mut x: u64, mut y: u64) -> u64{
    assert!(x !=0 && y != 0);
    while y != 0 {
        if dbg!(x < y) {
            mem::swap(&mut y, &mut x);
        } else {
            x %= y;
        }
        dbg!(x, y);
    }
    x
}

fn get_form(_request: &mut Request) -> IronResult<Response> {
    let mut response = Response::new();

    response.set_mut(status::Ok);
    response.set_mut(mime!(Text/Html; Charset=Utf8));
    response.set_mut(r#"
        <title>GCD Calculator</title>
        <form action="/gcd" method="post">
            <input type="text"  name="n">
            <input type="text"  name="n">
            <button type="submit"">Compute GCD</button>
        </form>
    "#);

    Ok(response)
}

fn post_gcd(request: &mut Request) -> IronResult<Response> {
    let mut response = Response::new();

    let form_data = match request.get_ref::<UrlEncodedBody>() {
        Err(e) => {
            response.set_mut(status::BadRequest);
            response.set_mut(format!("Error parsing from data: {:?}\n", e));
            return Ok(response);
        }
        Ok(map) => map
    };

    let unparsed_numbers = match form_data.get("n") {
        None => {
            response.set_mut(status::BadRequest);
            response.set_mut(format!("form data has no 'n' parameters "));
            return Ok(response); 
        },
        Some(nums) => nums
    };

    let mut numbers = Vec::new();
    for unparsed in unparsed_numbers {
        match u64::from_str(&unparsed) {
            Err(_) => {
                response.set_mut(status::BadRequest);
                response.set_mut(format!("Value for n parameter not a number {:?}\n", unparsed));
                return Ok(response);
            }
            Ok(n) => numbers.push(n)
        }
    }
    let mut d = numbers[0];
    for m in &numbers[1..] {
        d = gcd(d, *m);
    }

    response.set_mut(status::Ok);
    response.set_mut(mime!(Text/Html; Charset=Utf8));
    response.set_mut(format!("The greatest common divisor of the numbres {:?} is <b>{}</b>\n", numbers, d));

    Ok(response)
}
