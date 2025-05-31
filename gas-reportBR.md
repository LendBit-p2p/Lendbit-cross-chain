| contracts/Diamond.sol:Diamond contract |                 |         |         |         |         |
| -------------------------------------- | --------------- | ------- | ------- | ------- | ------- |
| Deployment Cost                        | Deployment Size |         |         |         |         |
| 568565                                 | 5415            |         |         |         |         |
| Function Name                          | min             | avg     | median  | max     | # calls |
| closeListingAd                         | 55326           | 55326   | 55326   | 55326   | 1       |
| closeRequest                           | 75590           | 75590   | 75590   | 75590   | 1       |
| createLendingRequest                   | 177562          | 606398  | 639605  | 639985  | 15      |
| createLoanListing                      | 192720          | 216490  | 216200  | 236208  | 8       |
| depositCollateral                      | 75726           | 107987  | 112212  | 117012  | 23      |
| diamondCut                             | 1461756         | 1461756 | 1461756 | 1461756 | 34      |
| facetAddresses                         | 2315            | 2315    | 2315    | 2315    | 34      |
| getAccountAvailableValue               | 135775          | 135775  | 135775  | 135775  | 1       |
| getAllRequest                          | 8680            | 8680    | 8680    | 8680    | 1       |
| getConvertValue                        | 54936           | 54936   | 54936   | 54936   | 1       |
| getHealthFactor                        | 33415           | 117040  | 143415  | 147915  | 4       |
| getLoanListing                         | 4952            | 4952    | 4952    | 4952    | 5       |
| getRequest                             | 3913            | 5113    | 5913    | 5913    | 10      |
| getRequestToColateral                  | 3365            | 3365    | 3365    | 3365    | 2       |
| getServicedRequestByLender             | 7367            | 7367    | 7367    | 7367    | 1       |
| getUsdValue                            | 7701            | 17451   | 17451   | 27201   | 2       |
| getUserActiveRequests                  | 5972            | 5972    | 5972    | 5972    | 2       |
| getUserCollateralTokens                | 37493           | 37493   | 37493   | 37493   | 1       |
| getUserRequest                         | 6001            | 6001    | 6001    | 6001    | 4       |
| gets_addressToAvailableBalance         | 1287            | 3001    | 3287    | 3287    | 7       |
| gets_addressToCollateralDeposited      | 1310            | 3192    | 3310    | 3310    | 17      |
| initialize                             | 410808          | 410808  | 410808  | 410808  | 34      |
| liquidateUserRequest                   | 0               | 0       | 0       | 0       | 1       |
| receive                                | 21055           | 21055   | 21055   | 21055   | 1       |
| repayLoan                              | 44540           | 147148  | 168556  | 200657  | 5       |
| requestLoanFromListing                 | 188111          | 614727  | 828035  | 828035  | 3       |
| serviceRequest                         | 31749           | 310491  | 379382  | 399021  | 13      |
| setBotAddress                          | 51158           | 51158   | 51158   | 51158   | 34      |
| setSwapRouter                          | 34042           | 34042   | 34042   | 34042   | 34      |
| swapToLoanCurrency                     | 0               | 5369    | 0       | 16108   | 3       |
| withdrawCollateral                     | 48946           | 48952   | 48952   | 48958   | 2       |


| contracts/facets/DiamondCutFacet.sol:DiamondCutFacet contract |                 |         |         |         |         |
| ------------------------------------------------------------- | --------------- | ------- | ------- | ------- | ------- |
| Deployment Cost                                               | Deployment Size |         |         |         |         |
| 977810                                                        | 4313            |         |         |         |         |
| Function Name                                                 | min             | avg     | median  | max     | # calls |
| diamondCut                                                    | 1424266         | 1424266 | 1424266 | 1424266 | 34      |


| contracts/facets/DiamondLoupeFacet.sol:DiamondLoupeFacet contract |                 |      |        |      |         |
| ----------------------------------------------------------------- | --------------- | ---- | ------ | ---- | ------- |
| Deployment Cost                                                   | Deployment Size |      |        |      |         |
| 406220                                                            | 1666            |      |        |      |         |
| Function Name                                                     | min             | avg  | median | max  | # calls |
| facetAddresses                                                    | 1770            | 1770 | 1770   | 1770 | 34      |


| contracts/facets/ProtocolFacet.sol:ProtocolFacet contract |                 |         |         |         |         |
| --------------------------------------------------------- | --------------- | ------- | ------- | ------- | ------- |
| Deployment Cost                                           | Deployment Size |         |         |         |         |
| 5025463                                                   | 23054           |         |         |         |         |
| Function Name                                             | min             | avg     | median  | max     | # calls |
| closeListingAd                                            | 33901           | 33901   | 33901   | 33901   | 1       |
| closeRequest                                              | 49365           | 49365   | 49365   | 49365   | 1       |
| createLendingRequest                                      | 150562          | 579475  | 612621  | 612989  | 15      |
| createLoanListing                                         | 165576          | 189235  | 188972  | 208872  | 8       |
| depositCollateral                                         | 49358           | 82450   | 90416   | 90416   | 23      |
| getAccountAvailableValue                                  | 133251          | 133251  | 133251  | 133251  | 1       |
| getAllRequest                                             | 6002            | 6002    | 6002    | 6002    | 1       |
| getConvertValue                                           | 49903           | 49903   | 49903   | 49903   | 1       |
| getHealthFactor                                           | 32891           | 113766  | 139641  | 142891  | 4       |
| getLoanListing                                            | 2386            | 2386    | 2386    | 2386    | 5       |
| getRequest                                                | 3323            | 3323    | 3323    | 3323    | 10      |
| getRequestToColateral                                     | 838             | 838     | 838     | 838     | 2       |
| getServicedRequestByLender                                | 4765            | 4765    | 4765    | 4765    | 1       |
| getUsdValue                                               | 5168            | 13668   | 13668   | 22168   | 2       |
| getUserActiveRequests                                     | 3445            | 3445    | 3445    | 3445    | 2       |
| getUserCollateralTokens                                   | 34963           | 34963   | 34963   | 34963   | 1       |
| getUserRequest                                            | 3408            | 3408    | 3408    | 3408    | 4       |
| gets_addressToAvailableBalance                            | 760             | 760     | 760     | 760     | 7       |
| gets_addressToCollateralDeposited                         | 783             | 783     | 783     | 783     | 17      |
| liquidateUserRequest                                      | 1351926         | 1351926 | 1351926 | 1351926 | 1       |
| repayLoan                                                 | 18108           | 132237  | 161316  | 179029  | 5       |
| requestLoanFromListing                                    | 161727          | 588329  | 801631  | 801631  | 3       |
| serviceRequest                                            | 5149            | 288378  | 362386  | 372653  | 13      |
| setBotAddress                                             | 24705           | 24705   | 24705   | 24705   | 34      |
| setSwapRouter                                             | 7613            | 7613    | 7613    | 7613    | 34      |
| swapToLoanCurrency                                        | 0               | 49769   | 70243   | 79064   | 3       |
| withdrawCollateral                                        | 22518           | 22518   | 22518   | 22518   | 2       |
