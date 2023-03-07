#![feature(test)]

extern crate rand;

use std::error;
use std::hash::{Hash, Hasher};
use std::collections::hash_map::DefaultHasher;
use bytecount;

use std::fmt;

// テストケース
#[cfg(test)]
mod tests {
    use super::*;
    use test::Bencher;

    #[test]
    fn create_hll() {
        assert!(HyperLogLog::new(3).is_err());
        assert!(HyperLogLog::new(17).is_err());

        let hll = HyperLogLog::new(4);
        assert!(hll.is_ok());

        let hll = hll.unwrap();
        assert_eq!(hll.b, 4);
        // assert_eq!(hll.m, 2_usize.pow(4));
        assert!(hll.alpha - 0.673f64 < std::f64::EPSILON);
        assert_eq!(hll.registers.len(), 2_usize.pow(4));

        assert!(HyperLogLog::new(16).is_ok());
    }

    #[test]
    fn small_range() {
        let mut hll = HyperLogLog::new(12).unwrap();
        let items = ["test1", "test2", "test3", "test2", "test2", "test2"];

        println!("\n=== Loading {} items.\n", items.len());
        for item in &items {
            hll.update(item);
        }
    }

    #[bench]
    fn bench_add_two(b: &mut Bencher) {
        b.iter(|| small_range());
    }
}

/// `HyperLogLog` オブジェクト
pub struct HyperLogLog {
    // レジスタのアドレッシングに使う２進数のビット数。
    // 範囲は 4以上、16以下で、大きいほど見積もり誤差が小さくなるが、その分メモリを使用する。
    b: u8,
    m: usize,
    // TODO: const_fn usize 型のハッシュ値の右からbビットを取り出すためのマスク
    b_mask: usize,
    // TODO:const_fn レジスタの数（２のb乗）。例：b = 4 → 16、b = 16 → 65536
    alpha: f64,
    // レジスタ。サイズが m バイトのバイト配列
    registers: Vec<u8>,
}

/// ビット数 b に対応する α 値を返す。
fn get_alpha(b: u8) -> Result<f64, Box<dyn error::Error>> {
    if b < 4 || b > 16 {
        Err(From::from(format!("b must be between 4 and 16. b = {}", b)))
    } else {
        Ok(match b {
            4 => 0.673, // α16
            5 => 0.697, // α32
            6 => 0.709, // α64
            _ => 0.7213 / (1.0 + 1.079 / (1 << b) as f64),
        })
    }
}

/// ハッシュ値（64ビット符号なし２進数）の左端から見て最初に出現した 1 の位置を返す。
/// 例：10000... → 1、00010... → 4
fn position_of_leftmost_one_bit(s: u64, max_width: u8) -> u8 {
    count_leading_zeros(s, max_width) + 1
}

/// ハッシュ値（64ビット符号なし２進数）左端に連続して並んでいる 0 の個数を返す。
/// 例：10000... → 0、00010... → 3
fn count_leading_zeros(mut s: u64, max_width: u8) -> u8 {
    let mut lz = max_width;
    while s != 0 {
        lz -= 1;
        s >>= 1;
    }
    lz
}

/// 推定アルゴリズム。デバッグ出力用
#[derive(Debug)]
pub enum Estimator {
    HyperLogLog,
    LinearCounting, // スモールレンジの見積もりに使用する。
}

impl HyperLogLog {
    /// `HyperLogLog` オブジェクトを作成する。b で指定したビット数をレジスタの
    /// アドレッシングに使用する。b の範囲は 4以上、16以下でなければならない。
    /// 範囲外なら `Err` を返す。
    pub fn new(b: u8) -> Result<Self, Box<dyn error::Error>> {
        if b < 4 || b > 16 {
            return Err(From::from(format!("b must be between 4 and 16. b = {}", b)));
        }

        let m = 1 << b;
        let alpha = get_alpha(b)?;

        Ok(HyperLogLog {
            alpha, b, m,
            b_mask: m - 1,
            // m: m,
            registers: vec![0; m],
        })
    }

    fn hash<H: Hash>(&self, value: &H) -> u64 {
        let mut hasher = DefaultHasher::new();
        value.hash(&mut hasher);
        hasher.finish()
    }

    pub fn update<H: Hash>(&mut self, value: &H)  {
        let x = self.hash(value);
        let j = x as usize & self.b_mask;
        let w = x >> self.b;

        let p1 = position_of_leftmost_one_bit(w, 64 - self.b);
        let p2 = &mut self.registers[j];
        if *p2 < p1 {
            *p2 = p1;
        }
    }

     pub fn cardinality(&self) -> f64 {
        estimate_cardinality(self).0
    }

    /// b から予想される典型的なエラー率を返す。
    pub fn typical_error_rate(&self) -> f64 {
        1.04 / (self.m as f64).sqrt()
    }

    /// `self` で示される `HyperLogLog` オブジェクトへ、`other` で示される別の
    /// `HyperLogLog` オブジェクトをマージする。両オブジェクトの設定が異なる場合は
    /// `Err` を返す。
    pub fn merge(&mut self, other: &HyperLogLog) -> Result<(), Box<dyn error::Error>> {
        if self.b == other.b && self.m == other.m {
            for (p1, p2) in self.registers.iter_mut().zip(other.registers.iter()) {
                if *p1 < *p2 {
                    *p1 = *p2
                }
            }
            Ok(())
        } else {
            Err(From::from(format!("Specs does not match. \
                                    b: {}|{}, m: {}|{}",
                                   self.b,
                                   other.b,
                                   self.m,
                                   other.m)))
        }
    }
}

/// `HyperLogLog` のデバッグ出力用文字列を返す。
impl fmt::Debug for HyperLogLog {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        let (est, est_method) = estimate_cardinality(self);
        write!(f,
               r#"HyperLogLog
  estimated cardinality: {}
  estimation method:     {:?}
  -----------------------------------------------------
  b:      {} bits (typical error rate: {}%)
  m:      {} registers
  alpha:  {}
  "#,
               est,
               est_method,
               self.b,
               self.typical_error_rate() * 100.0,
               self.m,
               self.alpha
               )
    }
}

/// カーディナリティを推定し、その値と、見積もりに使用したアルゴリズムを返す。
/// スモールレンジでは `Linear Counting` アルゴリズムを使用し、それを超えるレンジでは
/// `HyperLogLog` アルゴリズムを使用する。ここまでは論文の通り。
/// しかし、論文にあるラージレンジ補正は行なわない。なぜなら、本実装では、32 ビットの
/// ハッシュ値の代わりに 64 ビットのハッシュ値を使用しており、ハッシュ値が衝突する頻度が
/// 極めて低いと予想されるため。
fn estimate_cardinality(hll: &HyperLogLog) -> (f64, Estimator) {
    let m_f64 = hll.m as f64;
    // まず `HyperLogLog` アルゴリズムによる見積もり値を算出する。
    let est = raw_hyperloglog_estimate(hll.alpha, m_f64, &hll.registers);

    if est < (5.0 / 2.0 * m_f64) {
        // スモールレンジの見積もりを行う。もし値が 0 のレジスタが１つでもあるなら、
        // `Linear Counting` アルゴリズムで見積もり直す。
        match count_zero_registers(&hll.registers) {
            0 => (est, Estimator::HyperLogLog),
            v => (linear_counting_estimate(m_f64, v as f64), Estimator::LinearCounting),
        }
    } else {
        (est, Estimator::HyperLogLog)
    }
}

/// 値が 0 のレジスタの個数を返す。
fn count_zero_registers(registers: &[u8]) -> usize {
    bytecount::count(registers, b'\0')
}

/// `HyperLogLog` アルゴリズムによる未補正の見積もり値を算出する。
fn raw_hyperloglog_estimate(alpha: f64, m: f64, registers: &[u8]) -> f64 {
    let sum = registers.iter().map(|&x| 2.0f64.powi(-(x as i32))).sum::<f64>();
    alpha * m * m / sum
}

/// `Linear Counting` アルゴリズムによる見積もり値を算出する。
fn linear_counting_estimate(m: f64, number_of_zero_registers: f64) -> f64 {
    m * (m / number_of_zero_registers).ln()
}
