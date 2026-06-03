import SwiftUI

struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var scale: CGFloat
    var opacity: Double
    var speedX: CGFloat
    var speedY: CGFloat
}

struct ParticleEffect: View {
    let particleCount: Int
    @State private var particles: [Particle] = []
    
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 4, height: 4) // Prevents expansion
                        .scaleEffect(particle.scale)
                        .opacity(particle.opacity)
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
            }
            .onReceive(timer) { _ in
                updateParticles(in: geometry.size)
            }
        }
    }
    
    private func createParticles(in size: CGSize) {
        particles = (0..<particleCount).map { _ in
            Particle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                scale: CGFloat.random(in: 0.2...1.5),
                opacity: Double.random(in: 0.1...0.5),
                speedX: CGFloat.random(in: -1...1),
                speedY: CGFloat.random(in: -1...1)
            )
        }
    }
    
    private func updateParticles(in size: CGSize) {
        for index in particles.indices {
            var particle = particles[index]
            
            particle.x += particle.speedX
            particle.y += particle.speedY
            
            // Wrap around
            if particle.x < 0 { particle.x = size.width }
            else if particle.x > size.width { particle.x = 0 }
            
            if particle.y < 0 { particle.y = size.height }
            else if particle.y > size.height { particle.y = 0 }
            
            particles[index] = particle
        }
    }
}
