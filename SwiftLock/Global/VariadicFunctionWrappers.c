//
//  VariadicFunctionWrappers.c
//  SwiftLock
//
//  Created by Mohak Shah on 10/04/17.
//  Copyright © 2017 Mohak Shah. All rights reserved.
//

#include "VariadicFunctionWrappers.h"

int
vfw_open(const char *path, int oflag) {
    return open(path, oflag);
}
