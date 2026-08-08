# Task 15 Plan Summary

| Query | Phase | Plan hash | Root op | Cost | Est rows | Seek | Scan | Sort | Hash | Key lookup | Operators |
|---|---|---|---|---:|---:|---|---|---|---|---|---|
| Q1 | after | 0x0A21C726B5C1C4FB | Nested Loops / Inner Join | 0.137677 | 66.2109 | True | False | True | False | False | Clustered Index Seek:2, Filter:1, Index Seek:1, Nested Loops:2, Sort:1 |
| Q1 | before | 0x24B5326A72F36CA7 | Nested Loops / Inner Join | 0.167248 | 66.2109 | True | False | True | True | False | Clustered Index Seek:3, Filter:2, Hash Match:1, Index Seek:2, Nested Loops:3, Sort:1 |
| Q2 | after | 0x08208FFCD3415A7B | Compute Scalar / Compute Scalar | 0.162393 | 1 | True | True | True | False | False | Clustered Index Scan:3, Clustered Index Seek:2, Compute Scalar:4, Filter:3, Index Seek:4, Index Spool:1, Nested Loops:8, Sort:2, Stream Aggregate:3 |
| Q2 | before | 0x9FE5ED624C086A79 | Compute Scalar / Compute Scalar | 0.780531 | 1 | True | True | True | True | False | Clustered Index Scan:3, Clustered Index Seek:3, Compute Scalar:4, Filter:3, Hash Match:2, Index Seek:6, Index Spool:1, Nested Loops:9, Sort:2, Stream Aggregate:3 |
| Q3 | after | 0x297D42516A74A491 | Sort / Sort | 0.379568 | 120 | True | True | True | True | False | Clustered Index Scan:1, Compute Scalar:4, Filter:1, Hash Match:2, Index Seek:1, Sort:1 |
| Q3 | before | 0xB061942267FAA70F | Sort / Sort | 1.609480 | 120 | False | True | True | True | False | Clustered Index Scan:2, Compute Scalar:4, Filter:1, Hash Match:2, Sort:1 |
| Q5 | after | 0xFA124FEA4E55386F | Compute Scalar / Compute Scalar | 0.325612 | 15.2147 | True | True | True | False | False | Clustered Index Scan:1, Clustered Index Seek:7, Compute Scalar:3, Index Seek:3, Nested Loops:10, Sort:1 |
| Q5 | before | 0x61AF3367616520B9 | Compute Scalar / Compute Scalar | 0.406860 | 15.2178 | True | True | True | False | False | Clustered Index Scan:1, Clustered Index Seek:8, Compute Scalar:3, Index Seek:3, Nested Loops:11, Sort:1 |
