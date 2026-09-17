add_circt_unittest(CIRCTFIRRTLTests
  AttributesTest.cpp
  ChoiceOpsTest.cpp
  PortsTest.cpp
  TypesTest.cpp
)

target_link_libraries(CIRCTFIRRTLTests
  PRIVATE
  CIRCTFIRRTL
)
