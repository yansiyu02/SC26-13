import SpriteKit
import SwiftUI
import TypingFarmerCore

struct FarmSpritePlot: Equatable, Identifiable {
    let keyID: String
    let rect: CGRect
    let isMature: Bool
    let wasRecentlyHit: Bool
    let soilStage: Int

    var id: String {
        keyID
    }
}

struct FarmSpritePet: Equatable, Identifiable {
    let id: UUID
    let species: PetSpecies
    let assetPrefix: String
}

struct FarmSpriteLayer: NSViewRepresentable {
    var plots: [FarmSpritePlot]
    var pets: [FarmSpritePet]
    var harvestEvents: [HarvestAnimationEvent]
    var onPetCollect: (UUID, String) -> Bool = { _, _ in true }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SKView {
        let view = SKView(frame: .zero)
        view.allowsTransparency = true
        view.ignoresSiblingOrder = true
        view.presentScene(context.coordinator.scene)
        return view
    }

    func updateNSView(_ view: SKView, context: Context) {
        let scene = context.coordinator.scene
        if scene.size != view.bounds.size {
            scene.size = view.bounds.size
            scene.layoutField()
        }
        scene.onPetCollect = onPetCollect
        scene.updateFarm(plots: plots, pets: pets, harvestEvents: harvestEvents)
    }

    final class Coordinator {
        fileprivate let scene = FarmSpriteScene(size: .zero)
    }
}

fileprivate final class FarmSpriteScene: SKScene {
    private let fieldNode = SKNode()
    private let ambientNode = SKNode()
    private let highlightNode = SKNode()
    private let particleNode = SKNode()
    private let petLayerNode = SKNode()
    private let dogNode = SKNode()
    private var dogSpriteNode: SKSpriteNode?
    private var dogIdleTexture: SKTexture?
    private var dogRunTextures: [SKTexture] = []
    private var dogCollectTexture: SKTexture?
    private var dogProneTexture: SKTexture?
    private var dogSleepTexture: SKTexture?
    private var lastMatureCount = 0
    private var lastRecentHitCount = 0
    private var lastPlotSignature = ""
    private var seenHarvestEventIDs: Set<UUID> = []
    private var currentPlots: [FarmSpritePlot] = []
    private var currentPets: [FarmSpritePet] = []
    private var petRenderStates: [UUID: PetRenderState] = [:]
    var onPetCollect: (UUID, String) -> Bool = { _, _ in true }

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
        addChild(fieldNode)
        addChild(ambientNode)
        addChild(highlightNode)
        addChild(particleNode)
        addChild(petLayerNode)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didChangeSize(_ oldSize: CGSize) {
        layoutField()
    }

    func layoutField() {
        fieldNode.removeAllChildren()
        ambientNode.removeAllChildren()
        guard size.width > 1, size.height > 1 else {
            return
        }

        layoutPets()
        addAmbientLeaves()
    }

    func updateFarm(plots: [FarmSpritePlot], pets: [FarmSpritePet], harvestEvents: [HarvestAnimationEvent]) {
        currentPlots = plots
        currentPets = pets
        syncPetNodes()
        rebuildHighlightsIfNeeded(for: plots)

        let matureCount = plots.filter(\.isMature).count
        let recentHitCount = plots.filter(\.wasRecentlyHit).count
        if matureCount > lastMatureCount {
            emitSparkles(count: min(10, matureCount - lastMatureCount + 3), color: NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.18, alpha: 0.9))
        }
        if recentHitCount > lastRecentHitCount {
            emitSparkles(count: min(8, recentHitCount - lastRecentHitCount + 2), color: NSColor(calibratedRed: 0.62, green: 1.0, blue: 0.36, alpha: 0.75))
        }

        lastMatureCount = matureCount
        lastRecentHitCount = recentHitCount

        for event in harvestEvents where !seenHarvestEventIDs.contains(event.id) {
            seenHarvestEventIDs.insert(event.id)
            animateHarvest(event: event)
        }
        if seenHarvestEventIDs.count > 48 {
            seenHarvestEventIDs = Set(harvestEvents.suffix(24).map(\.id))
        }
    }

    private func emitSparkles(count: Int, color: NSColor) {
        guard size.width > 1, size.height > 1 else {
            return
        }

        for _ in 0..<count {
            let node = SKShapeNode(circleOfRadius: CGFloat.random(in: 2.5...5.5))
            node.fillColor = color
            node.strokeColor = .clear
            let minX = min(size.width / 2, 36)
            let maxX = max(minX, size.width - minX)
            let minY = min(size.height / 2, 34)
            let maxY = max(minY, size.height - minY)
            node.position = CGPoint(
                x: CGFloat.random(in: minX...maxX),
                y: CGFloat.random(in: minY...maxY)
            )
            node.alpha = 0
            particleNode.addChild(node)

            let rise = SKAction.moveBy(x: CGFloat.random(in: -18...18), y: CGFloat.random(in: 18...42), duration: Double.random(in: 0.65...1.05))
            rise.timingMode = .easeOut
            node.run(
                .sequence([
                    .group([.fadeIn(withDuration: 0.08), .scale(to: 1.25, duration: 0.12)]),
                    .group([rise, .fadeOut(withDuration: 0.8)]),
                    .removeFromParent()
                ])
            )
        }
    }

    private func rebuildHighlightsIfNeeded(for plots: [FarmSpritePlot]) {
        // SwiftUI updates this representable often. A compact signature avoids
        // rebuilding pulsing highlight nodes unless the visible plot state moved.
        let signature = plots.map { plot in
            "\(plot.keyID):\(Int(plot.rect.minX)):\(Int(plot.rect.minY)):\(Int(plot.rect.width)):\(Int(plot.rect.height)):\(plot.isMature):\(plot.wasRecentlyHit):\(plot.soilStage)"
        }.joined(separator: "|")
        guard signature != lastPlotSignature else {
            return
        }

        lastPlotSignature = signature
        highlightNode.removeAllChildren()
    }

    private func animateHarvest(event: HarvestAnimationEvent) {
        guard size.width > 1, size.height > 1 else {
            return
        }

        let plotRect = currentPlots.first { $0.keyID == event.keyID }?.rect
        let target = plotRect.map { scenePoint(from: CGPoint(x: $0.midX, y: $0.midY)) }
            ?? CGPoint(x: size.width * 0.5, y: size.height * 0.55)

        switch event.source {
        case .pet(let source):
            guard let renderState = petRenderStates[source.petID] else {
                return
            }
            let petIndex = currentPets.firstIndex { $0.id == source.petID } ?? 0
            let petTarget = petHarvestPosition(near: target, index: petIndex)
            renderState.node.removeAllActions()
            renderState.node.xScale = petTarget.x < renderState.node.position.x ? -renderState.scale : renderState.scale
            let move = SKAction.move(to: petTarget, duration: min(1.6, max(0.55, renderState.node.position.distance(to: petTarget) / 260)))
            move.timingMode = .easeInEaseOut
            renderState.node.run(.sequence([
                .run { [weak self, weak renderState] in
                    guard let renderState else { return }
                    self?.startRunAnimation(for: renderState)
                },
                move,
                .run { [weak self, weak renderState] in
                    guard let self, let renderState else { return }
                    self.setPetTexture(renderState.collectTexture, for: renderState)
                },
                .wait(forDuration: 0.32),
                .run { [weak self] in
                    guard let self, self.onPetCollect(source.petID, event.keyID) else {
                        return
                    }
                    self.emitCoinFlight(from: target, coins: event.coins)
                    self.emitSparkles(around: target, color: NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.18, alpha: 0.9))
                },
                .wait(forDuration: 0.32),
                .run { [weak self, weak renderState] in
                    guard let self, let renderState else { return }
                    self.setRandomRestPose(for: renderState)
                },
                .wait(forDuration: 0.22),
                .run { [weak self, weak renderState] in
                    guard let self, let renderState else { return }
                    self.resumePetPatrol(for: renderState, index: petIndex)
                }
            ]))
        case .player:
            emitCoinFlight(from: target, coins: event.coins)
            emitSparkles(around: target, color: NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.18, alpha: 0.9))
        }
    }

    private func emitCoinFlight(from start: CGPoint, coins: Int) {
        let hudTarget = CGPoint(x: size.width - 52, y: size.height + 24)
        let coin = SKShapeNode(circleOfRadius: 11)
        coin.fillColor = NSColor(calibratedRed: 1.0, green: 0.73, blue: 0.18, alpha: 0.96)
        coin.strokeColor = NSColor(calibratedWhite: 1, alpha: 0.78)
        coin.lineWidth = 2.2
        coin.position = start
        coin.zPosition = 20
        particleNode.addChild(coin)

        let label = SKLabelNode(text: "+\(coins)")
        label.fontName = "Menlo-Bold"
        label.fontSize = 20
        label.fontColor = NSColor(calibratedWhite: 1, alpha: 0.95)
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: start.x + 24, y: start.y + 8)
        label.zPosition = 21
        particleNode.addChild(label)

        let fly = SKAction.move(to: hudTarget, duration: 0.86)
        fly.timingMode = .easeInEaseOut
        coin.run(.sequence([.group([fly, .scale(to: 0.62, duration: 0.86)]), .removeFromParent()]))
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 30, duration: 0.78), .fadeOut(withDuration: 0.78)]),
            .removeFromParent()
        ]))
    }

    private func emitSparkles(around point: CGPoint, color: NSColor) {
        for _ in 0..<7 {
            let node = SKShapeNode(circleOfRadius: CGFloat.random(in: 2.5...5))
            node.fillColor = color
            node.strokeColor = .clear
            node.position = CGPoint(
                x: point.x + CGFloat.random(in: -20...20),
                y: point.y + CGFloat.random(in: -14...18)
            )
            particleNode.addChild(node)
            node.run(.sequence([
                .group([
                    .moveBy(x: CGFloat.random(in: -14...14), y: CGFloat.random(in: 18...36), duration: 0.72),
                    .fadeOut(withDuration: 0.72)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func syncPetNodes() {
        let petIDs = Set(currentPets.map(\.id))
        for (id, renderState) in petRenderStates where !petIDs.contains(id) {
            renderState.node.removeFromParent()
            petRenderStates[id] = nil
        }

        for (index, pet) in currentPets.enumerated() {
            if let renderState = petRenderStates[pet.id] {
                renderState.scale = petScale(for: index)
                renderState.node.zPosition = 12 + CGFloat(index) * 0.2
                renderState.updateSpriteSize(petSpriteSize(for: index))
                if renderState.node.parent == nil {
                    petLayerNode.addChild(renderState.node)
                }
                if renderState.node.position == .zero, size.width > 1, size.height > 1 {
                    renderState.node.position = petPatrolPoint(for: index, isRightSide: false)
                    resumePetPatrol(for: renderState, index: index)
                }
            } else {
                let renderState = makePetRenderState(for: pet, index: index)
                petRenderStates[pet.id] = renderState
                petLayerNode.addChild(renderState.node)
                if size.width > 1, size.height > 1 {
                    renderState.node.position = petPatrolPoint(for: index, isRightSide: false)
                    resumePetPatrol(for: renderState, index: index)
                }
            }
        }
    }

    private func makePetRenderState(for pet: FarmSpritePet, index: Int) -> PetRenderState {
        let size = petSpriteSize(for: index)
        let renderState = PetRenderState(
            id: pet.id,
            species: pet.species,
            assetPrefix: pet.assetPrefix,
            scale: petScale(for: index),
            spriteSize: size,
            textureLoader: loadTexture(named:)
        )
        renderState.node.zPosition = 12 + CGFloat(index) * 0.2
        if renderState.spriteNode == nil {
            buildFallbackPet(in: renderState.node, species: pet.species)
        }
        return renderState
    }

    private func layoutPets() {
        guard size.width > 1, size.height > 1 else {
            return
        }
        syncPetNodes()
    }

    private func petLaneY(for index: Int) -> CGFloat {
        24 + CGFloat(index % 3) * 8
    }

    private func petScale(for index: Int) -> CGFloat {
        1 - CGFloat(min(index, 4)) * 0.045
    }

    private func petSpriteSize(for index: Int) -> CGSize {
        let scale = petScale(for: index)
        return CGSize(width: 60 * scale, height: 60 * scale)
    }

    private func petPatrolPoint(for index: Int, isRightSide: Bool) -> CGPoint {
        let laneY = petLaneY(for: index)
        let offset = CGFloat((index % 5) * 24)
        if isRightSide {
            return CGPoint(x: max(88, size.width - 72 - offset), y: laneY)
        }
        return CGPoint(x: min(max(58 + offset, 42), max(42, size.width - 42)), y: laneY)
    }

    private func petHarvestPosition(near target: CGPoint, index: Int) -> CGPoint {
        let preferredY = target.y - 26 - CGFloat(index % 2) * 5
        let preferredX = target.x + CGFloat((index % 3) - 1) * 14
        return CGPoint(
            x: min(max(preferredX, 42), max(42, size.width - 42)),
            y: min(max(preferredY, 30), max(30, size.height - 42))
        )
    }

    private func resumePetPatrol(for renderState: PetRenderState, index: Int) {
        guard size.width > 1, size.height > 1 else {
            return
        }
        renderState.node.removeAction(forKey: "patrol")
        let left = petPatrolPoint(for: index, isRightSide: false)
        let right = petPatrolPoint(for: index, isRightSide: true)
        let moveRight = SKAction.move(to: right, duration: Double.random(in: 5.5...8.0))
        moveRight.timingMode = .easeInEaseOut
        let moveLeft = SKAction.move(to: left, duration: Double.random(in: 5.5...8.0))
        moveLeft.timingMode = .easeInEaseOut
        let scale = renderState.scale
        renderState.node.run(.repeatForever(.sequence([
            .wait(forDuration: Double(index) * 0.22),
            .run { [weak self, weak renderState] in
                guard let renderState else { return }
                renderState.node.xScale = scale
                self?.startRunAnimation(for: renderState)
            },
            moveRight,
            .run { [weak self, weak renderState] in
                guard let renderState else { return }
                self?.setRandomRestPose(for: renderState)
            },
            .wait(forDuration: Double.random(in: 1.1...2.4)),
            .run { [weak self, weak renderState] in
                guard let renderState else { return }
                renderState.node.xScale = -scale
                self?.startRunAnimation(for: renderState)
            },
            moveLeft,
            .run { [weak self, weak renderState] in
                guard let renderState else { return }
                self?.setRandomRestPose(for: renderState)
            },
            .wait(forDuration: Double.random(in: 1.2...2.6))
        ])), withKey: "patrol")
    }

    private func startRunAnimation(for renderState: PetRenderState) {
        guard let sprite = renderState.spriteNode, !renderState.runTextures.isEmpty else {
            resumeFallbackPetMotion(for: renderState)
            return
        }
        sprite.removeAction(forKey: "pose")
        sprite.run(.repeatForever(.animate(with: renderState.runTextures, timePerFrame: 0.09, resize: false, restore: false)), withKey: "pose")
    }

    private func setRandomRestPose(for renderState: PetRenderState) {
        setPetTexture(renderState.restTextures.randomElement() ?? renderState.idleTexture, for: renderState)
    }

    private func setPetTexture(_ texture: SKTexture?, for renderState: PetRenderState) {
        guard let sprite = renderState.spriteNode, let texture = texture ?? renderState.idleTexture else {
            resumeFallbackPetMotion(for: renderState)
            return
        }
        sprite.removeAction(forKey: "pose")
        sprite.texture = texture
        sprite.size = renderState.spriteSize
    }

    private func buildFallbackPet(in node: SKNode, species: PetSpecies) {
        let body = SKShapeNode(ellipseOf: CGSize(width: 38, height: 20))
        body.fillColor = species == .cat
            ? NSColor(calibratedRed: 0.86, green: 0.58, blue: 0.34, alpha: 1)
            : NSColor(calibratedRed: 0.62, green: 0.40, blue: 0.22, alpha: 1)
        body.strokeColor = NSColor(calibratedWhite: 0.18, alpha: 0.35)
        body.lineWidth = 1
        node.addChild(body)

        let head = SKShapeNode(circleOfRadius: 12)
        head.fillColor = body.fillColor
        head.strokeColor = NSColor(calibratedWhite: 0.18, alpha: 0.32)
        head.position = CGPoint(x: 22, y: 7)
        node.addChild(head)

        let eye = SKShapeNode(circleOfRadius: 1.8)
        eye.fillColor = NSColor(calibratedWhite: 0.08, alpha: 1)
        eye.strokeColor = .clear
        eye.position = CGPoint(x: 27, y: 9)
        node.addChild(eye)

        let tailPath = CGMutablePath()
        tailPath.move(to: CGPoint(x: -20, y: 5))
        tailPath.addQuadCurve(to: CGPoint(x: -34, y: 14), control: CGPoint(x: -28, y: 14))
        let tail = SKShapeNode(path: tailPath)
        tail.strokeColor = body.fillColor
        tail.lineWidth = species == .cat ? 3 : 4
        tail.lineCap = .round
        tail.name = "tail"
        node.addChild(tail)
    }

    private func resumeFallbackPetMotion(for renderState: PetRenderState) {
        guard let tail = renderState.node.childNode(withName: "tail") else {
            return
        }
        tail.removeAllActions()
        tail.run(.repeatForever(.sequence([
            .rotate(toAngle: 0.24, duration: 0.18, shortestUnitArc: true),
            .rotate(toAngle: -0.18, duration: 0.18, shortestUnitArc: true)
        ])))
    }

    private func buildDog() {
        dogNode.removeAllChildren()
        dogNode.zPosition = 12

        dogSpriteNode = nil
        dogIdleTexture = loadTexture(named: "pet_dog_idle") ?? loadTexture(named: "pet_dog")
        dogRunTextures = (1...4).compactMap { loadTexture(named: "pet_dog_run_\($0)") }
        dogCollectTexture = loadTexture(named: "pet_dog_collect")
        dogProneTexture = loadTexture(named: "pet_dog_prone")
        dogSleepTexture = loadTexture(named: "pet_dog_sleep")

        if let dogIdleTexture {
            let sprite = SKSpriteNode(texture: dogIdleTexture)
            sprite.size = dogSpriteSize
            sprite.position = CGPoint(x: 0, y: 8)
            sprite.name = "sprite"
            dogSpriteNode = sprite
            dogNode.addChild(sprite)
            return
        }

        buildFallbackDog()
    }

    private var dogLaneY: CGFloat {
        28
    }

    private var dogSpriteSize: CGSize {
        CGSize(width: 60, height: 60)
    }

    private func dogHarvestPosition(near target: CGPoint) -> CGPoint {
        let preferredY = target.y - 26
        return CGPoint(
            x: min(max(target.x, 42), max(42, size.width - 42)),
            y: min(max(preferredY, 30), max(30, size.height - 42))
        )
    }

    private func buildFallbackDog() {
        let body = SKShapeNode(ellipseOf: CGSize(width: 38, height: 20))
        body.fillColor = NSColor(calibratedRed: 0.62, green: 0.40, blue: 0.22, alpha: 1)
        body.strokeColor = NSColor(calibratedWhite: 0.18, alpha: 0.35)
        body.lineWidth = 1
        body.position = CGPoint(x: 0, y: 0)
        dogNode.addChild(body)

        let head = SKShapeNode(circleOfRadius: 12)
        head.fillColor = NSColor(calibratedRed: 0.68, green: 0.45, blue: 0.25, alpha: 1)
        head.strokeColor = NSColor(calibratedWhite: 0.18, alpha: 0.32)
        head.position = CGPoint(x: 22, y: 7)
        dogNode.addChild(head)

        let ear = SKShapeNode(ellipseOf: CGSize(width: 9, height: 14))
        ear.fillColor = NSColor(calibratedRed: 0.36, green: 0.22, blue: 0.12, alpha: 1)
        ear.strokeColor = .clear
        ear.position = CGPoint(x: 17, y: 5)
        dogNode.addChild(ear)

        let eye = SKShapeNode(circleOfRadius: 1.8)
        eye.fillColor = NSColor(calibratedWhite: 0.08, alpha: 1)
        eye.strokeColor = .clear
        eye.position = CGPoint(x: 27, y: 9)
        dogNode.addChild(eye)

        let tailPath = CGMutablePath()
        tailPath.move(to: CGPoint(x: -20, y: 5))
        tailPath.addQuadCurve(to: CGPoint(x: -34, y: 14), control: CGPoint(x: -28, y: 14))
        let tail = SKShapeNode(path: tailPath)
        tail.strokeColor = NSColor(calibratedRed: 0.62, green: 0.40, blue: 0.22, alpha: 1)
        tail.lineWidth = 4
        tail.lineCap = .round
        tail.name = "tail"
        dogNode.addChild(tail)

        resumeTailWag()
    }

    private func loadTexture(named name: String) -> SKTexture? {
        let url = Bundle.module.url(forResource: name, withExtension: "png")
            ?? Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Art")
        guard let url, let image = NSImage(contentsOf: url) else {
            return nil
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }

    private func layoutDogIfNeeded() {
        guard dogNode.position == .zero, size.width > 1, size.height > 1 else {
            return
        }
        dogNode.position = CGPoint(x: 58, y: dogLaneY)
        resumeDogPatrol()
    }

    private func resumeDogPatrol() {
        guard size.width > 1, size.height > 1 else {
            return
        }
        dogNode.removeAction(forKey: "patrol")
        let left = CGPoint(x: 58, y: dogLaneY)
        let right = CGPoint(x: max(88, size.width - 72), y: dogLaneY)
        let moveRight = SKAction.move(to: right, duration: Double.random(in: 5.5...8.0))
        moveRight.timingMode = .easeInEaseOut
        let moveLeft = SKAction.move(to: left, duration: Double.random(in: 5.5...8.0))
        moveLeft.timingMode = .easeInEaseOut
        dogNode.run(.repeatForever(.sequence([
            .run { [weak self] in
                self?.dogNode.xScale = 1
                self?.startDogRunAnimation()
            },
            moveRight,
            .run { [weak self] in self?.setRandomDogRestPose() },
            .wait(forDuration: Double.random(in: 1.4...2.8)),
            .run { [weak self] in
                self?.dogNode.xScale = -1
                self?.startDogRunAnimation()
            },
            moveLeft,
            .run { [weak self] in self?.setRandomDogRestPose() },
            .wait(forDuration: Double.random(in: 1.4...2.8)),
            .run { [weak self] in self?.resumeTailWag() }
        ])), withKey: "patrol")
    }

    private func startDogRunAnimation() {
        guard let dogSpriteNode, !dogRunTextures.isEmpty else {
            resumeTailWag()
            return
        }
        dogSpriteNode.removeAction(forKey: "pose")
        dogSpriteNode.run(.repeatForever(.animate(with: dogRunTextures, timePerFrame: 0.11, resize: false, restore: false)), withKey: "pose")
    }

    private func setRandomDogRestPose() {
        setDogTexture(Bool.random() ? dogProneTexture : dogSleepTexture)
    }

    private func setDogTexture(_ texture: SKTexture?) {
        guard let dogSpriteNode, let texture = texture ?? dogIdleTexture else {
            resumeTailWag()
            return
        }
        dogSpriteNode.removeAction(forKey: "pose")
        dogSpriteNode.texture = texture
        dogSpriteNode.size = dogSpriteSize
    }

    private func resumeTailWag() {
        guard let tail = dogNode.childNode(withName: "tail") else {
            return
        }
        tail.removeAllActions()
        tail.run(.repeatForever(.sequence([
            .rotate(toAngle: 0.24, duration: 0.18, shortestUnitArc: true),
            .rotate(toAngle: -0.18, duration: 0.18, shortestUnitArc: true)
        ])))
    }

    private func addAmbientLeaves() {
        guard size.width > 1, size.height > 1 else {
            return
        }
        for index in 0..<7 {
            let leaf = SKShapeNode(ellipseOf: CGSize(width: 7, height: 3.5))
            leaf.fillColor = NSColor(calibratedRed: 0.68, green: 0.92, blue: 0.38, alpha: 0.24)
            leaf.strokeColor = .clear
            leaf.position = CGPoint(
                x: CGFloat.random(in: 18...(max(20, size.width - 18))),
                y: CGFloat.random(in: 28...(max(30, size.height - 24)))
            )
            leaf.zRotation = CGFloat.random(in: -0.7...0.7)
            ambientNode.addChild(leaf)

            let drift = SKAction.moveBy(x: CGFloat.random(in: -18...18), y: CGFloat.random(in: -6...10), duration: Double.random(in: 3.5...6.5))
            drift.timingMode = .easeInEaseOut
            leaf.run(.repeatForever(.sequence([
                .wait(forDuration: Double(index) * 0.4),
                drift,
                drift.reversed()
            ])))
        }
    }

    private func sceneRect(from rect: CGRect) -> CGRect {
        // Plot rects come from SwiftUI's top-left coordinate space; SpriteKit's
        // scene origin is bottom-left, so every overlay target is vertically flipped.
        CGRect(
            x: rect.minX,
            y: size.height - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    private func scenePoint(from point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: size.height - point.y)
    }
}

fileprivate final class PetRenderState {
    let id: UUID
    let species: PetSpecies
    let assetPrefix: String
    let node = SKNode()
    var scale: CGFloat
    var spriteSize: CGSize
    var spriteNode: SKSpriteNode?
    var idleTexture: SKTexture?
    var runTextures: [SKTexture]
    var collectTexture: SKTexture?
    var restTextures: [SKTexture]

    init(
        id: UUID,
        species: PetSpecies,
        assetPrefix: String,
        scale: CGFloat,
        spriteSize: CGSize,
        textureLoader: (String) -> SKTexture?
    ) {
        self.id = id
        self.species = species
        self.assetPrefix = assetPrefix
        self.scale = scale
        self.spriteSize = spriteSize
        idleTexture = textureLoader("\(assetPrefix)_idle") ?? textureLoader(assetPrefix)
        runTextures = (1...4).compactMap { textureLoader("\(assetPrefix)_run_\($0)") }
        collectTexture = textureLoader("\(assetPrefix)_collect")
        restTextures = [
            textureLoader("\(assetPrefix)_rest"),
            textureLoader("\(assetPrefix)_sleep"),
            textureLoader("\(assetPrefix)_prone")
        ].compactMap { $0 }

        if let idleTexture {
            let sprite = SKSpriteNode(texture: idleTexture)
            sprite.size = spriteSize
            sprite.position = CGPoint(x: 0, y: 8)
            sprite.name = "sprite"
            spriteNode = sprite
            node.addChild(sprite)
        }
        node.xScale = scale
        node.yScale = scale
    }

    func updateSpriteSize(_ size: CGSize) {
        spriteSize = size
        spriteNode?.size = size
        node.yScale = scale
    }
}

private extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        hypot(x - point.x, y - point.y)
    }
}
