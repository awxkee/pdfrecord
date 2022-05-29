//
//  BufferReadStream.hpp
//  Document Scanner
//
//  Created by Radzivon Bartoshyk on 07/05/2022.
//

#ifndef BufferReadStream_hpp
#define BufferReadStream_hpp

#include <stdio.h>
#include <vector>
#include "IByteReaderWithPosition.h"

class BufferReadStream: public IByteReaderWithPosition {
public:
    ~BufferReadStream();
    BufferReadStream(char* buffer, size_t size);
    void SetPosition(LongFilePositionType inOffsetFromStart);
    void SetPositionFromEnd(LongFilePositionType inOffsetFromEnd);
    LongFilePositionType GetCurrentPosition();
    void Skip(LongBufferSizeType inSkipSize);
    void Reset();
    IOBasicTypes::LongBufferSizeType Read(IOBasicTypes::Byte* inBuffer, IOBasicTypes::LongBufferSizeType inBufferSize);
    bool NotEnded();
private:
    std::vector<char> buffer;
    unsigned long pointer;
};

#endif /* BufferReadStream_hpp */
