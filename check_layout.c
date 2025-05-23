#include <stdio.h>
#include <stddef.h>
#include <CL/cl.h>

struct OuijaHostResult {
    char seed[9];
    cl_uchar _padding0;
    cl_ushort TotalScore;
    cl_uchar NegativeJokers;
    cl_uchar ScoreWants[16];
    cl_uchar _padding1;
};

int main() {
    printf(\ Memory layout of OuijaHostResult:\n\);
    printf(\Total size: %zu bytes\n\, sizeof(struct OuijaHostResult));
    printf(\Offset of seed: %zu\n\, offsetof(struct OuijaHostResult, seed));
    printf(\Offset of _padding0: %zu\n\, offsetof(struct OuijaHostResult, _padding0));
    printf(\Offset of TotalScore: %zu\n\, offsetof(struct OuijaHostResult, TotalScore));
    printf(\Offset of NegativeJokers: %zu\n\, offsetof(struct OuijaHostResult, NegativeJokers));
    printf(\Offset of ScoreWants: %zu\n\, offsetof(struct OuijaHostResult, ScoreWants));
    printf(\Offset of _padding1: %zu\n\, offsetof(struct OuijaHostResult, _padding1));
    return 0;
}
