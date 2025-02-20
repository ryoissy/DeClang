//===-- TestTypeDefs.td - Test dialect type definitions ----*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// TableGen data type definitions for Test dialect.
//
//===----------------------------------------------------------------------===//

#ifndef TEST_TYPEDEFS
#define TEST_TYPEDEFS

// To get the test dialect def.
include "TestOps.td"

// All of the types will extend this class.
class Test_Type<string name> : TypeDef<Test_Dialect, name> { }

def SimpleTypeA : Test_Type<"SimpleA"> {
  let mnemonic = "smpla";
}

// A more complex parameterized type.
def CompoundTypeA : Test_Type<"CompoundA"> {
  let mnemonic = "cmpnd_a";

  // List of type parameters.
  let parameters = (
    ins
    "int":$widthOfSomething,
    "::mlir::Type":$oneType,
    // This is special syntax since ArrayRefs require allocation in the
    // constructor.
    ArrayRefParameter<
      "int", // The parameter C++ type.
      "An example of an array of ints" // Parameter description.
      >: $arrayOfInts
  );

  let extraClassDeclaration = [{
    struct SomeCppStruct {};
  }];
}

// An example of how one could implement a standard integer.
def IntegerType : Test_Type<"TestInteger"> {
  let mnemonic = "int";
  let genVerifyInvariantsDecl = 1;
  let parameters = (
    ins
    // SignednessSemantics is defined below.
    "::mlir::test::TestIntegerType::SignednessSemantics":$signedness,
    "unsigned":$width
  );

  // We define the printer inline.
  let printer = [{
    $_printer << "int<";
    printSignedness($_printer, getImpl()->signedness);
    $_printer << ", " << getImpl()->width << ">";
  }];

  // The parser is defined here also.
  let parser = [{
    if (parser.parseLess()) return Type();
    SignednessSemantics signedness;
    if (parseSignedness($_parser, signedness)) return mlir::Type();
    if ($_parser.parseComma()) return Type();
    int width;
    if ($_parser.parseInteger(width)) return Type();
    if ($_parser.parseGreater()) return Type();
    Location loc = $_parser.getEncodedSourceLoc($_parser.getNameLoc());
    return getChecked(loc, signedness, width);
  }];

  // Any extra code one wants in the type's class declaration.
  let extraClassDeclaration = [{
    /// Signedness semantics.
    enum SignednessSemantics {
      Signless, /// No signedness semantics
      Signed,   /// Signed integer
      Unsigned, /// Unsigned integer
    };

    /// This extra function is necessary since it doesn't include signedness
    static IntegerType getChecked(unsigned width, Location location);

    /// Return true if this is a signless integer type.
    bool isSignless() const { return getSignedness() == Signless; }
    /// Return true if this is a signed integer type.
    bool isSigned() const { return getSignedness() == Signed; }
    /// Return true if this is an unsigned integer type.
    bool isUnsigned() const { return getSignedness() == Unsigned; }
  }];
}

// A parent type for any type which is just a list of fields (e.g. structs,
// unions).
class FieldInfo_Type<string name> : Test_Type<name> {
  let parameters = (
    ins
    // An ArrayRef of something which requires allocation in the storage
    // constructor.
    ArrayRefOfSelfAllocationParameter<
      "::mlir::test::FieldInfo", // FieldInfo is defined/declared in TestTypes.h.
      "Models struct fields">: $fields
  );

  // Prints the type in this format:
  //   struct<[{field1Name, field1Type}, {field2Name, field2Type}]
  let printer = [{
    $_printer << "struct" << "<";
    for (size_t i=0, e = getImpl()->fields.size(); i < e; i++) {
      const auto& field = getImpl()->fields[i];
      $_printer << "{" << field.name << "," << field.type << "}";
      if (i < getImpl()->fields.size() - 1)
          $_printer << ",";
    }
    $_printer << ">";
  }];

  // Parses the above format
  let parser = [{
    llvm::SmallVector<FieldInfo, 4> parameters;
    if ($_parser.parseLess()) return Type();
    while (mlir::succeeded($_parser.parseOptionalLBrace())) {
      StringRef name;
      if ($_parser.parseKeyword(&name)) return Type();
      if ($_parser.parseComma()) return Type();
      Type type;
      if ($_parser.parseType(type)) return Type();
      if ($_parser.parseRBrace()) return Type();
      parameters.push_back(FieldInfo {name, type});
      if ($_parser.parseOptionalComma()) break;
    }
    if ($_parser.parseGreater()) return Type();
    return get($_ctxt, parameters);
  }];
}

def StructType : FieldInfo_Type<"Struct"> {
    let mnemonic = "struct";
}

#endif // TEST_TYPEDEFS
