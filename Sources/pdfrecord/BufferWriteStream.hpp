//
//  BufferWriteStream.hpp
//  Document Scanner
//
//  Created by Radzivon Bartoshyk on 07/05/2022.
//

#ifndef BufferWriteStream_hpp
#define BufferWriteStream_hpp

#include "IByteWriterWithPosition.h"
#include <stdio.h>
#include <vector>

class BufferWriterStream: public IByteWriterWithPosition {
public:
    ~BufferWriterStream();
    BufferWriterStream();
    IOBasicTypes::LongFilePositionType GetCurrentPosition();
    IOBasicTypes::LongBufferSizeType Write(const IOBasicTypes::Byte* inBuffer,IOBasicTypes::LongBufferSizeType inSize);
    char* getBuffer(unsigned long* size);
private:
    std::vector<char> buffer;
};

#endif /* BufferWriteStream_hpp */
